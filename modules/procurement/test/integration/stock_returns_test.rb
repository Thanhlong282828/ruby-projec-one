require "test_helper"
require "minitest/mock"
require_relative "../support/return_fixtures"

class StockReturnsTest < ActionDispatch::IntegrationTest
  include ReturnFixtures
  def setup
    @buyer = make_user(:manager)
    @maker = make_user(:employee)
    @order = receipt_order(@maker, @buyer)
    @warehouse = stock_catalog(@buyer, :warehouse)
    @item = stock_catalog(@buyer, :item)
    @entry = post_stock(@buyer, receive_order(@buyer, @order), @warehouse, @item)
    @second = post_stock(@buyer, receive_order(@buyer, @order, receiving_attributes(@order, quantity: "6")), @warehouse, @item)
    @invalid = HrmProcurement::Domain::Services::RequestContent::Invalid
    @conflict = HrmProcurement::Domain::Services::RequestConflict
  end
  test "returns subtract three then one from the original four without consuming the other receipt" do
    original = [ @order, @entry.goods_receipt, @entry, @entry.movements.first ].map(&:attributes)
    record = return_stock(@buyer, @entry)
    assert_equal "posted", record.status
    assert_equal @order.supplier_id, record.supplier_id
    assert_equal @entry.warehouse_id, record.warehouse_id
    assert_equal @entry.movements.first.id, record.lines.first.stock_movement_id
    assert_equal BigDecimal("7"), balances(@buyer, @warehouse)[:records].first[:quantity]
    ledger = stock_ledger_for(@buyer, @warehouse, @item)
    assert_equal 3, ledger[:count]
    assert_equal BigDecimal("7"), ledger[:quantity]
    assert_equal [ BigDecimal("-3"), BigDecimal("4"), BigDecimal("6") ], ledger[:records].map(&:quantity).sort
    row = return_source(@buyer, @entry)[:lines].first
    assert_equal BigDecimal("3"), row[:returned]
    assert_equal BigDecimal("1"), row[:remaining]
    return_stock(@buyer, @entry, return_attributes(@entry, quantity: "1"))
    assert_equal BigDecimal("6"), balances(@buyer, @warehouse)[:records].first[:quantity]
    assert_raises(@conflict) { return_stock(@buyer, @entry, return_attributes(@entry, quantity: "0.001")) }
    assert_equal BigDecimal("0"), return_source(@buyer, @entry)[:lines].first[:remaining]
    assert_equal(original, [ @order, @entry.goods_receipt, @entry, @entry.movements.first ].map { |source| source.reload.attributes })
  end
  test "replay is immutable conflict sensitive and read only after post grant revoked" do
    attrs = return_attributes(@entry)
    record = return_stock(@buyer, @entry, attrs)
    assert_no_difference([ "StockReturn.count", "StockReturnLine.count", "AuditLog.count", "OutboxEvent.count" ]) do
      assert_equal record.id, return_stock(@buyer, @entry, attrs.merge(items: attrs[:items].map { |row| row.merge("quantity" => "3.000") })).id
    end
    assert_raises(@conflict) { return_stock(@buyer, @second, return_attributes(@second, key: attrs[:idempotency_key])) }
    assert_raises(@conflict) { return_stock(@buyer, @entry, attrs.merge(reason: "Khác")) }
    assert_raises(@conflict) { return_stock(@buyer, @entry, return_attributes(@entry, quantity: "1", key: attrs[:idempotency_key])) }
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.returns.post"), granted: false)
    assert_equal record.id, return_stock(@buyer, @entry, attrs).id
    assert_raises(Pundit::NotAuthorizedError) { return_stock(@buyer, @entry, return_attributes(@entry, quantity: "1")) }
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.returns.read"), granted: false)
    assert_raises(Pundit::NotAuthorizedError) { return_stock(@buyer, @entry, attrs) }
  end
  test "normalized decimal payload replays while invalid quantities and malformed content fail" do
    attrs = return_attributes(@entry, quantity: "0.125")
    record = return_stock(@buyer, @entry, attrs)
    assert_equal BigDecimal("0.125"), record.lines.first.quantity
    assert_equal record.id, return_stock(@buyer, @entry, attrs.merge(items: attrs[:items].map { |row| row.merge("quantity" => "0.125") })).id
    [ "0", "-1", "0.0001", "1e0", "NaN", "1,5", 0.1, [] ].each do |value|
      assert_raises(@invalid) { return_stock(@buyer, @entry, return_attributes(@entry, quantity: value)) }
    end
    malformed = "\xFF".dup.force_encoding(Encoding::UTF_8)
    assert_raises(@invalid) { return_stock(@buyer, @entry, attrs.merge(idempotency_key: malformed)) }
    assert_raises(@invalid) { return_stock(@buyer, @entry, return_attributes(@entry, quantity: malformed)) }
    assert_raises(@invalid) { return_stock(@buyer, @entry, attrs.merge(items: { malformed => attrs[:items].first })) }
    assert_raises(@invalid) { return_stock(@buyer, @entry, attrs.merge(reason: " ")) }
    assert_raises(@invalid) { return_stock(@buyer, @entry, attrs.merge(idempotency_key: [])) }
    assert_raises(@invalid) { return_stock(@buyer, @entry, attrs.merge(items: attrs[:items] * 2)) }
    assert_raises(@invalid) { return_stock(@buyer, @entry, attrs.merge(items: [])) }
    assert_equal BigDecimal("9.875"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
  test "foreign or unrelated movements and forged destination fields cannot change the source" do
    attrs = return_attributes(@entry).merge(company_id: -1, warehouse_id: -1, supplier_id: -1, stock_item_id: -1, status: "posted")
    record = return_stock(@buyer, @entry, attrs)
    assert_equal @buyer.company_id, record.company_id
    assert_equal @warehouse.id, record.warehouse_id
    assert_equal @item.id, record.lines.first.stock_item_id
    assert_raises(@invalid) { return_stock(@buyer, @entry, return_attributes(@second)) }
    company = Company.create!(code: "RET#{SecureRandom.hex(4).upcase}", name: "Return company two")
    buyer = make_user(:admin, company: company)
    warehouse = stock_catalog(buyer, :warehouse)
    item = stock_catalog(buyer, :item)
    entry = post_stock(buyer, receive_order(buyer, receipt_order(make_user(:employee, company: company), buyer)), warehouse, item)
    assert_raises(ActiveRecord::RecordNotFound) { return_stock(@buyer, entry) }
    assert_raises(@invalid) { return_stock(@buyer, @entry, return_attributes(entry)) }
    assert_equal BigDecimal("4"), balances(buyer, warehouse)[:records].first[:quantity]
    assert_raises(ActiveRecord::RecordNotFound) { stock_query.find_stock_return!(actor: buyer, id: record.id) }
    purchase_login(buyer)
    get stock_return_path(record)
    assert_response :not_found
    get new_stock_return_path(stock_receipt_id: @entry.id)
    assert_response :not_found
  end
  test "unposted sources are rejected and inactive historical catalogs still permit returning original goods" do
    receipt = receive_order(@buyer, receipt_order(@maker, @buyer))
    entry = StockReceipt.create!(company_id: @buyer.company_id, goods_receipt: receipt, warehouse: @warehouse, posted_by: @buyer,
      code: "IN-UNSEALED", mapping_digest: "a" * 64, warehouse_code_snapshot: @warehouse.code, warehouse_name_snapshot: @warehouse.name)
    assert_raises(@conflict) { return_stock(@buyer, entry, return_attributes(@entry)) }
    catalog_update(@buyer, @warehouse, :warehouse, status: "inactive")
    catalog_update(@buyer, @item, :item, status: "inactive")
    assert_equal "posted", return_stock(@buyer, @entry).status
  end
  test "journal failure after return lines rolls back header lines audit outbox and balance" do
    [ HrmAudit::Domain::Repositories::WriteRepositoryInterface, HrmPlatform::Domain::Repositories::OutboxRepositoryInterface ].each do |contract|
      repository = Hrm::Container.resolve(contract)
      implementation = repository.class
      original = implementation.instance_method(:append!)
      implementation.define_method(:append!) do |**args|
        record = args[:record]
        if (record.is_a?(StockReturn) && record.status == "posted") || (args[:event_type] == "stock_return.updated")
          raise "return journal failed after lines"
        end
        original.bind_call(self, **args)
      end
      begin
        assert_no_difference([ "StockReturn.count", "StockReturnLine.count", "AuditLog.count", "OutboxEvent.count" ]) do
          assert_raises(RuntimeError) { return_stock(@buyer, @entry) }
        end
        assert_equal BigDecimal("10"), balances(@buyer, @warehouse)[:records].first[:quantity]
      ensure
        implementation.define_method(:append!, original)
      end
    end
  end
  test "model and SQL protect posted documents lines and source deletion" do
    record = return_stock(@buyer, @entry)
    assert_not record.update(reason: "changed")
    assert_not record.lines.first.update(quantity: 1)
    assert_raises(ActiveRecord::DeleteRestrictionError) { record.destroy }
    connection = ActiveRecord::Base.connection
    [ "UPDATE stock_returns SET status='posting',posted_at=NULL WHERE id=#{record.id}",
      "DELETE FROM stock_returns WHERE id=#{record.id}",
      "UPDATE stock_return_lines SET quantity=1 WHERE stock_return_id=#{record.id}",
      "DELETE FROM stock_return_lines WHERE stock_return_id=#{record.id}",
      "DELETE FROM purchase_orders WHERE id=#{@order.id}" ].each do |sql|
      assert_raises(ActiveRecord::StatementInvalid) { connection.execute(sql) }
    end
    assert_equal BigDecimal("7"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
  test "HTTP navigation creates source bound return and ledger links respect independent read grants" do
    purchase_login(@buyer)
    get stock_receipt_path(@entry)
    assert_select "a[href=?]", new_stock_return_path(stock_receipt_id: @entry.id), text: "Trả hàng nhà cung cấp"
    get new_stock_return_path(stock_receipt_id: @entry.id)
    assert_response :success
    assert_select "label", text: "Lý do trả hàng (bắt buộc)"
    assert_select "input[name='stock_return[warehouse_id]']", count: 0
    attrs = return_attributes(@entry).merge(stock_receipt_id: @entry.id)
    post stock_returns_path, params: { stock_return: attrs }
    record = StockReturn.order(:id).last
    assert_redirected_to stock_return_path(record)
    follow_redirect!
    assert_select "a[href=?]", stock_receipt_path(@entry)
    get stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: @item.id)
    assert_select "tbody tr", count: 3
    assert_select "tbody", text: /-3.0/
    assert_select "a[href=?]", stock_return_path(record)
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.returns.read"), granted: false)
    get stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: @item.id)
    assert_response :success
    assert_select "a[href=?]", stock_return_path(record), count: 0
    assert_select "tbody", text: /-3.0/
    get stock_return_path(record)
    assert_response :forbidden
    get stock_returns_path
    assert_response :forbidden
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.receipts.read"), granted: false)
    get stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: @item.id)
    assert_response :success
    assert_select "tbody a", count: 0
    assert_select "tbody tr", count: 3
  end
  test "anonymous CSRF missing grants and validation fail closed at HTTP and direct command" do
    attrs = return_attributes(@entry).merge(stock_receipt_id: @entry.id)
    post stock_returns_path, params: { stock_return: attrs }
    assert_response :redirect
    assert_raises(Pundit::NotAuthorizedError) { return_stock(@maker, @entry) }
    purchase_login(@buyer)
    post stock_returns_path, params: { stock_return: attrs.merge(reason: "") }
    assert_response :unprocessable_content
    assert_select "input[name=?][value='3']", "stock_return[items][0][quantity]"
    assert_select "input[name='stock_return[idempotency_key]'][value=?]", attrs[:idempotency_key]
    post stock_returns_path, params: { stock_return: [] }
    assert_response :bad_request
    prior = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    assert_no_difference("StockReturn.count") { post stock_returns_path, params: { stock_return: attrs } }
    assert_response :unprocessable_content
  ensure
    ActionController::Base.allow_forgery_protection = prior unless prior.nil?
  end
  test "decimal and multiple original lines of one SKU preserve per movement entitlement" do
    attrs = purchase_attributes.merge(items: [ { description: "A", quantity: "1.125", unit: "cái", estimated_unit_price: "100" }, { description: "B", quantity: "0.001", unit: "cái", estimated_unit_price: "100" } ])
    order = issue_order(@buyer, create_order(@buyer, approved_source(@maker, @buyer, attributes: attrs), supplier_for(@buyer, code: "MULTI")))
    receipt = receive_order(@buyer, order, { idempotency_key: SecureRandom.uuid, received_on: Date.current.iso8601,
      items: order.lines.map { |line| { "purchase_order_line_id" => line.id.to_s, "quantity" => line.quantity.to_s("F") } } })
    entry = post_stock(@buyer, receipt, @warehouse, @item)
    lines = entry.movements.to_a
    input = { idempotency_key: SecureRandom.uuid, reason: "Decimal", items: lines.map { |line| { "stock_movement_id" => line.id.to_s, "quantity" => line.quantity.to_s("F") } } }
    record = return_stock(@buyer, entry, input)
    assert_equal BigDecimal("1.126"), record.lines.sum(:quantity)
    assert_equal BigDecimal("10"), balances(@buyer, @warehouse)[:records].first[:quantity]
    assert_raises(@conflict) { return_stock(@buyer, entry, return_attributes(entry, quantity: "0.001")) }
  end
  test "mixed ledger pages have stable identities global totals and unchanged source filters" do
    26.times { return_stock(@buyer, @entry, return_attributes(@entry, quantity: "0.001")) }
    first = stock_ledger_for(@buyer, @warehouse, @item)
    second = stock_ledger_for(@buyer, @warehouse, @item, page: 2)
    assert_equal 28, first[:count]
    assert_equal 25, first[:records].size
    assert_equal 3, second[:records].size
    assert_equal BigDecimal("9.974"), first[:quantity]
    assert_equal first[:quantity], second[:quantity]
    identity = ->(row) { [ row[:document_kind], row.id ] }
    assert_empty first[:records].map(&identity) & second[:records].map(&identity)
    assert_equal first[:records].map(&identity), stock_ledger_for(@buyer, @warehouse, @item)[:records].map(&identity)
    purchase_login(@buyer)
    get stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: @item.id)
    assert_select "a[href=?]", stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: @item.id, page: 2), text: "Trang tiếp"
    get stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: @item.id, page: 2)
    assert_select "tbody tr", count: 3
    assert_select ".panel strong", text: "9.974 cái"
    assert_select "a[href=?]", stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: @item.id, page: 1), text: "Trang trước"
  end
  test "MySQL seal refuses empty over returned and cross source lines without weakening immutable guards" do
    record = return_stock(@buyer, @entry)
    header_attributes = record.attributes.except("id", "created_at", "updated_at").merge("status" => "posting", "posted_at" => nil)
    make_header = -> { StockReturn.create!(header_attributes.merge("code" => "RT-#{SecureRandom.hex(6)}", "idempotency_key" => SecureRandom.uuid)) }
    assert_raises(ActiveRecord::StatementInvalid) do
      StockReturn.transaction(requires_new: true) do
        header = make_header.call
        header.update!(status: "posted", posted_at: Time.current)
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      StockReturn.transaction(requires_new: true) do
        header = make_header.call
        StockReturnLine.create!(record.lines.first.attributes.except("id", "created_at", "updated_at").merge("stock_return_id" => header.id, "quantity" => "2"))
        header.update!(status: "posted", posted_at: Time.current)
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      StockReturn.transaction(requires_new: true) do
        header = make_header.call
        other = @second.movements.first
        values = record.lines.first.attributes.except("id", "created_at", "updated_at").merge("stock_return_id" => header.id, "stock_receipt_id" => @second.id, "stock_movement_id" => other.id, "quantity" => "1", "created_at" => Time.current, "updated_at" => Time.current)
        # rubocop:disable Rails/SkipsModelValidations -- Exercise composite foreign keys against a direct SQL insert bypassing model validation.
        StockReturnLine.insert_all!([ values ])
        # rubocop:enable Rails/SkipsModelValidations
      end
    end
    assert_equal BigDecimal("7"), balances(@buyer, @warehouse)[:records].first[:quantity]
    assert_equal "Hàng lỗi kiểm chứng", record.reason
    raw = ActiveRecord::Base.connection.select_value("SELECT reason FROM stock_returns WHERE id=#{record.id}")
    assert_not_equal record.reason, raw
    assert_not_includes raw, record.reason
  end
  test "return realtime metadata requires the current return read grant and case sensitive keys stay distinct" do
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: @buyer, message: { type: "stock_return.updated", id: 1 })
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "realtime.read"), granted: true)
    assert Hrm::RealtimeAuthorization.allowed?(actor: @buyer, message: { type: "stock_return.updated", id: 1 })
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: @maker, message: { type: "stock_return.updated", id: 1 })
    one = return_stock(@buyer, @entry, return_attributes(@entry, quantity: "0.001", key: "A" * 16))
    two = return_stock(@buyer, @entry, return_attributes(@entry, quantity: "0.001", key: "a" * 16))
    assert_not_equal one.id, two.id
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.returns.read"), granted: false)
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: @buyer, message: { type: "stock_return.updated", id: 1 })
  end
  test "company key unique index fences raw competing inserts on different sources" do
    record = return_stock(@buyer, @entry)
    assert_raises(ActiveRecord::RecordNotUnique) do
      StockReturn.transaction(requires_new: true) do
        attributes = record.attributes.except("id", "created_at", "updated_at").merge("stock_receipt_id" => @second.id,
          "code" => "RT-OTHER-KEY", "status" => "posting", "posted_at" => nil)
        StockReturn.create!(attributes)
      end
    end
    assert_equal BigDecimal("7"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
  test "a real unique collision rolls back its savepoint and retries the full current authorization path" do
    record = return_stock(@buyer, @entry)
    tokens = [ record.code.split("-").last.downcase, "abcdef012345" ]
    fresh = nil
    SecureRandom.stub(:hex, ->(*) { tokens.shift || raise("Unexpected code generation") }) do
      fresh = return_stock(@buyer, @entry, return_attributes(@entry, quantity: "1"))
    end
    assert_equal "posted", fresh.status
    assert_not_equal record.id, fresh.id
    assert_equal BigDecimal("6"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
end
