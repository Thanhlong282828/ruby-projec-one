require "test_helper"
require "minitest/mock"
require_relative "../support/receipt_fixtures"
class GoodsReceiptsTest < ActionDispatch::IntegrationTest
  include ReceiptFixtures
  def setup
    @maker = make_user(:employee)
    @buyer = make_user(:manager)
    @order = receipt_order(@maker, @buyer)
    @repo = Hrm::Container.resolve(HrmProcurement::Domain::Repositories::ReadRepositoryInterface)
    @invalid = HrmProcurement::Domain::Services::RequestContent::Invalid
    @conflict = HrmProcurement::Domain::Services::RequestConflict
  end
  def progress
    @repo.find_order!(actor: @buyer, id: @order.id)[:progress]
  end
  test "ten ordered receive four then six immutable receipts and unchanged issued PO" do
    original = @order.attributes
    assert_equal "Chưa nhận", progress
    first = receive_order(@buyer, @order)
    assert_equal "recorded", first.status
    assert_equal BigDecimal("4"), first.lines.first.quantity
    assert_equal "Nhận một phần", progress
    assert_equal BigDecimal("4"), @repo.find_order!(actor: @buyer, id: @order.id)[:quantities].fetch(@order.lines.first.id)
    assert_equal 1, @repo.order_workspace(actor: @buyer, filters: { delivery: "pending", page: 1 })[:count]
    second = receive_order(@buyer, @order, receiving_attributes(@order, quantity: "6"))
    assert_not_equal first.id, second.id
    assert_equal "Đã nhận đủ", progress
    assert_equal 0, @repo.order_workspace(actor: @buyer, filters: { delivery: "pending", page: 1 })[:count]
    assert_raises(@conflict) { receive_order(@buyer, @order, receiving_attributes(@order, quantity: "0.001")) }
    assert_equal original, @order.reload.attributes
    assert_raises(ActiveRecord::RecordNotSaved) { first.update!(received_on: Date.tomorrow) }
    assert_raises(ActiveRecord::DeleteRestrictionError) { first.destroy! }
    assert_equal 2, GoodsReceipt.where(company_id: @buyer.company_id).count
    assert_equal "DELIVERY-SAMPLE", first.reload.delivery_reference
    assert_not_includes first.attributes_before_type_cast.fetch("delivery_reference"), "DELIVERY-SAMPLE"
  end
  test "durable idempotency normalizes decimal and rejects conflicting key reuse even after completion" do
    input = receiving_attributes(@order, quantity: "10")
    first = receive_order(@buyer, @order, input)
    assert_no_difference([ "GoodsReceipt.count", "GoodsReceiptLine.count", "AuditLog.count", "OutboxEvent.count" ]) do
      assert_equal first.id, receive_order(@buyer, @order, input.merge(items: [ { "purchase_order_line_id" => @order.lines.first.id, "quantity" => "10.000" } ])).id
    end
    [ input.merge(received_on: "2026-11-14"), input.merge(delivery_reference: "OTHER"), input.merge(items: [ { "purchase_order_line_id" => @order.lines.first.id, "quantity" => "9" } ]) ].each do |changed|
      assert_raises(@conflict) { receive_order(@buyer, @order, changed) }
    end
    another = receipt_order(@maker, @buyer)
    assert_raises(@conflict) { receive_order(@buyer, another, receiving_attributes(another, key: input[:idempotency_key])) }
  end
  test "quantity date identity and malformed inputs fail before writing" do
    [ "-1", "1.0001", "1e0", "0.000", "NaN", 1.5, [], "1000000", " 1" ].each do |value|
      assert_raises(@invalid) { receive_order(@buyer, @order, receiving_attributes(@order, quantity: value)) }
    end
    input = receiving_attributes(@order)
    assert_raises(@invalid) { receive_order(@buyer, @order, input.merge(items: input[:items] * 2)) }
    assert_raises(@invalid) { receive_order(@buyer, @order, input.merge(items: [])) }
    assert_raises(@invalid) { receive_order(@buyer, @order, input.merge(idempotency_key: "bad")) }
    assert_raises(@invalid) { receive_order(@buyer, @order, input.merge(received_on: "2026-02-30")) }
    assert_equal 0, GoodsReceipt.count
  end
  test "draft wrong PO line foreign tenant revoked grants and scoped receipt reads fail closed" do
    other = Company.create!(code: "GR#{SecureRandom.hex(4).upcase}", name: "Other receiving sample")
    foreign_buyer = make_user(:manager, company: other)
    foreign_order = receipt_order(make_user(:employee, company: other), foreign_buyer)
    assert_raises(ActiveRecord::RecordNotFound) { receive_order(@buyer, foreign_order) }
    assert_raises(@invalid) { receive_order(@buyer, @order, receiving_attributes(foreign_order)) }
    draft = create_order(@buyer, approved_source(@maker, @buyer), supplier_for(@buyer, code: "DRAFT"))
    assert_raises(@conflict) { receive_order(@buyer, draft, receiving_attributes(draft)) }
    receipt = receive_order(@buyer, @order)
    assert_raises(ActiveRecord::RecordNotFound) { @repo.find_receipt!(actor: foreign_buyer, id: receipt.id) }
    assert_raises(Pundit::NotAuthorizedError) { receive_order(@maker, @order) }
    purchase_login(foreign_buyer)
    get goods_receipt_path(receipt)
    assert_response :not_found
    get new_goods_receipt_path(purchase_order_id: @order.id)
    assert_response :not_found
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "procurement.receipts.create"), granted: false)
    assert_raises(Pundit::NotAuthorizedError) { receive_order(@buyer, @order) }
    purchase_login(@buyer)
    get new_goods_receipt_path(purchase_order_id: @order.id)
    assert_response :forbidden
  end
  test "audit and outbox failures roll back header lines and progress" do
    [ AuditLog, OutboxEvent ].each do |model|
      assert_no_difference([ "GoodsReceipt.count", "GoodsReceiptLine.count", "AuditLog.count", "OutboxEvent.count" ]) do
        model.stub(:create!, ->(**_) { raise "Receiving journal unavailable" }) do
          assert_raises(RuntimeError) { receive_order(@buyer, @order) }
        end
      end
      assert_equal "Chưa nhận", progress
    end
  end
  test "journal failure after lines are inserted rolls back sealed receipt atomically" do
    [ AuditLog, OutboxEvent ].each do |model|
      original = model.method(:create!)
      calls = 0
      handler = lambda do |**args|
        calls += 1
        if calls == 2
          assert_equal BigDecimal("4"), GoodsReceiptLine.where(purchase_order_id: @order.id).sum(:quantity)
          raise "Final journal unavailable"
        end
        original.call(**args)
      end
      assert_no_difference([ "GoodsReceipt.count", "GoodsReceiptLine.count", "AuditLog.count", "OutboxEvent.count" ]) do
        model.stub(:create!, handler) { assert_raises(RuntimeError) { receive_order(@buyer, @order) } }
      end
      assert_equal "Chưa nhận", progress
    end
  end
  test "web KPI pending filter receipt links completion zero and hidden permission" do
    purchase_login(@buyer)
    get root_path
    assert_select "a[data-metric='pending_receipts'][href=?]", purchase_orders_path(delivery: "pending"), text: /1/
    get purchase_orders_path(delivery: "pending")
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /Quá ngày giao/
    get new_goods_receipt_path(purchase_order_id: @order.id)
    assert_response :success
    assert_select "input[step='0.001']"
    input = receiving_attributes(@order).merge(purchase_order_id: @order.id)
    post goods_receipts_path, params: { goods_receipt: input }
    receipt = GoodsReceipt.last
    assert_redirected_to goods_receipt_path(receipt)
    follow_redirect!
    assert_select "a[href=?]", purchase_order_path(@order)
    assert_select "a[href=?]", purchase_request_path(@order.purchase_request_id)
    get purchase_order_path(@order)
    assert_select "a[href=?]", goods_receipt_path(receipt)
    post goods_receipts_path, params: { goods_receipt: input.merge(items: [ { purchase_order_line_id: @order.lines.first.id, quantity: "1.0001" } ]) }
    assert_response :unprocessable_content
    assert_select "[role=alert]"
    receive_order(@buyer, @order, receiving_attributes(@order, quantity: "6"))
    get purchase_orders_path(delivery: "pending")
    assert_select "tbody tr", count: 0
    get root_path
    assert_select "a[data-metric='pending_receipts'] strong", text: "0"
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "procurement.orders.read"), granted: false)
    get root_path
    assert_select "a[data-metric='pending_receipts']", count: 0
    get purchase_orders_path(delivery: "pending")
    assert_response :forbidden
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "procurement.receipts.read"), granted: false)
    get goods_receipt_path(receipt)
    assert_response :forbidden
  end
  test "KPI and receipt sources stay isolated when logging into two companies" do
    other = Company.create!(code: "GRKPI#{SecureRandom.hex(4).upcase}", name: "Company two receipt sample")
    buyer = make_user(:admin, company: other)
    foreign = receipt_order(make_user(:employee, company: other), buyer)
    receipt = receive_order(@buyer, @order, receiving_attributes(@order, quantity: "10"))
    foreign_receipt = receive_order(buyer, foreign)
    purchase_login(@buyer)
    get root_path
    assert_select "a[data-metric='pending_receipts'] strong", text: "0"
    get goods_receipts_path
    assert_select "tbody a[href=?]", goods_receipt_path(receipt), count: 1
    assert_select "tbody a[href=?]", goods_receipt_path(foreign_receipt), count: 0
    purchase_login(buyer)
    get root_path
    assert_select "a[data-metric='pending_receipts'] strong", text: "1"
    get purchase_orders_path(delivery: "pending")
    assert_select "tbody a[href=?]", purchase_order_path(foreign, delivery: "pending", page: 1), count: 1
    assert_not_includes response.body, @order.code
    get goods_receipts_path
    assert_select "tbody a[href=?]", goods_receipt_path(foreign_receipt), count: 1
    assert_select "tbody a[href=?]", goods_receipt_path(receipt), count: 0
    get goods_receipt_path(receipt)
    assert_response :not_found
  end
  test "receipt realtime metadata requires a current receipt read grant" do
    admin = make_user(:admin)
    message = { type: "goods_receipt.updated", id: 1 }
    assert Hrm::RealtimeAuthorization.allowed?(actor: admin, message: message)
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: @maker, message: message)
    admin.user_permissions.create!(permission: Permission.find_by!(key: "procurement.receipts.read"), granted: false)
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: admin, message: message)
  end
  test "database refuses sealing an aggregate over receipt despite valid individual line" do
    receive_order(@buyer, @order)
    assert_raises(ActiveRecord::StatementInvalid) do
      GoodsReceipt.transaction(requires_new: true) do
        receipt = GoodsReceipt.create!(company_id: @buyer.company_id, purchase_order: @order, received_by: @buyer, code: "GR-GUARD", received_on: Date.current, idempotency_key: SecureRandom.uuid, content_digest: "a" * 64)
        receipt.lines.create!(company_id: @buyer.company_id, purchase_order_id: @order.id, purchase_order_line: @order.lines.first, quantity: 7)
        receipt.update!(status: "recorded")
      end
    end
    assert_equal 1, GoodsReceipt.where(purchase_order_id: @order.id).count
    assert_equal BigDecimal("4"), GoodsReceiptLine.where(purchase_order_id: @order.id).sum(:quantity)
  end
  test "database guards forbid issued receipt edits append and delete" do
    receipt = receive_order(@buyer, @order)
    # rubocop:disable Rails/SkipsModelValidations -- Exercise MySQL immutable receipt triggers, bypassing model callbacks deliberately.
    assert_raises(ActiveRecord::StatementInvalid) { receipt.update_columns(received_on: Date.tomorrow) }
    assert_raises(ActiveRecord::StatementInvalid) { receipt.lines.first.update_columns(quantity: 5) }
    assert_raises(ActiveRecord::StatementInvalid) { GoodsReceipt.where(id: receipt.id).delete_all }
    assert_raises(ActiveRecord::StatementInvalid) { receipt.lines.delete_all }
    values = receipt.lines.first.attributes.except("id").merge("quantity" => 1)
    assert_raises(ActiveRecord::StatementInvalid) { GoodsReceiptLine.insert_all!([ values ]) }
    # rubocop:enable Rails/SkipsModelValidations
  end
end
