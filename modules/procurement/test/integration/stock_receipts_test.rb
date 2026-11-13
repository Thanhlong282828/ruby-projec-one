require "test_helper"
require "minitest/mock"
require_relative "../support/stock_fixtures"
class StockReceiptsTest < ActionDispatch::IntegrationTest
  include StockFixtures
  def setup
    @maker = make_user(:employee)
    @buyer = make_user(:manager)
    @order = receipt_order(@maker, @buyer)
    @first = receive_order(@buyer, @order)
    @second = receive_order(@buyer, @order, receiving_attributes(@order, quantity: "6"))
    @warehouse = stock_catalog(@buyer, :warehouse)
    @item = stock_catalog(@buyer, :item)
    @invalid = HrmProcurement::Domain::Services::RequestContent::Invalid
    @conflict = HrmProcurement::Domain::Services::RequestConflict
  end
  test "two receipts post four plus six with source quantities and unchanged PO and receipt snapshots" do
    original_order = @order.attributes
    original_receipts = [ @first, @second ].map(&:attributes)
    assert_empty balances(@buyer)[:records]
    first = post_stock(@buyer, @first, @warehouse, @item)
    assert_equal "posted", first.status
    assert first.posted_at
    assert_equal @buyer.id, first.posted_by_id
    assert_equal BigDecimal("4"), balances(@buyer)[:records].first[:quantity]
    assert_equal @first.lines.first.purchase_order_line_id, first.movements.first.purchase_order_line_id
    assert_equal @first.lines.first.id, first.movements.first.goods_receipt_line_id
    second = post_stock(@buyer, @second, @warehouse, @item)
    assert_not_equal first.id, second.id
    assert_equal BigDecimal("10"), balances(@buyer, @warehouse)[:records].first[:quantity]
    assert_equal 1, balances(@buyer)[:count]
    assert_equal original_order, @order.reload.attributes
    assert_equal original_receipts, [ @first.reload, @second.reload ].map(&:attributes)
    assert_equal 0, stock_query.pending_stock_workspace(actor: @buyer, filters: { page: 1 })[:count]
  end
  test "same source same destination and mapping replay adds no movement audit or outbox" do
    record = post_stock(@buyer, @first, @warehouse, @item)
    assert_no_difference([ "StockReceipt.count", "StockMovement.count", "AuditLog.count", "OutboxEvent.count" ]) do
      assert_equal record.id, post_stock(@buyer, @first, @warehouse, @item).id
    end
    alternate_warehouse = stock_catalog(@buyer, :warehouse, code: "ALT")
    alternate_item = stock_catalog(@buyer, :item, code: "ALT")
    assert_raises(@conflict) { post_stock(@buyer, @first, alternate_warehouse, @item) }
    assert_raises(@conflict) { post_stock(@buyer, @first, @warehouse, alternate_item) }
    assert_equal BigDecimal("4"), balances(@buyer)[:records].first[:quantity]
  end
  test "full exact line mapping is mandatory and forged quantities cannot enter the ledger" do
    attrs = stock_attributes(@first, @warehouse, @item)
    assert_raises(@invalid) { post_stock(@buyer, @first, @warehouse, @item, attributes: attrs.merge(items: [])) }
    assert_raises(@invalid) { post_stock(@buyer, @first, @warehouse, @item, attributes: attrs.merge(items: attrs[:items] * 2)) }
    wrong = attrs[:items].map { |row| row.merge("goods_receipt_line_id" => @second.lines.first.id.to_s) }
    assert_raises(@invalid) { post_stock(@buyer, @first, @warehouse, @item, attributes: attrs.merge(items: wrong)) }
    attrs[:items].first["quantity"] = "999999.999"
    record = post_stock(@buyer, @first, @warehouse, @item, attributes: attrs)
    assert_equal BigDecimal("4"), record.movements.first.quantity
  end
  test "multiple received lines mapped to same stable item accumulate rather than overwrite" do
    attrs = purchase_attributes.merge(items: [ { description: "A", quantity: "1.125", unit: "cái", estimated_unit_price: "100" }, { description: "B", quantity: "0.001", unit: "cái", estimated_unit_price: "200" } ])
    order = issue_order(@buyer, create_order(@buyer, approved_source(@maker, @buyer, attributes: attrs), supplier_for(@buyer, code: "MULTI")))
    receipt = receive_order(@buyer, order, { idempotency_key: SecureRandom.uuid, received_on: Date.current.iso8601, items: order.lines.map { |line| { "purchase_order_line_id" => line.id.to_s, "quantity" => line.quantity.to_s("F") } } })
    record = post_stock(@buyer, receipt, @warehouse, @item)
    assert_equal 2, record.movements.size
    assert_equal BigDecimal("1.126"), balances(@buyer)[:records].first[:quantity]
    malformed = stock_attributes(receipt, @warehouse, @item)
    malformed[:items].pop
    assert_raises(@conflict) { post_stock(@buyer, receipt, @warehouse, @item, attributes: malformed) }
  end
  test "inactive catalogs remain readable historically but cannot be used for new posting" do
    record = post_stock(@buyer, @first, @warehouse, @item)
    catalog_update(@buyer, @warehouse, :warehouse, name: "Renamed warehouse", status: "inactive")
    catalog_update(@buyer, @item, :item, name: "Renamed item", status: "inactive")
    assert_equal record.id, post_stock(@buyer, @first, @warehouse, @item).id
    assert_raises(ActiveRecord::RecordNotFound) { post_stock(@buyer, @second, @warehouse, @item) }
    purchase_login(@buyer)
    get stock_receipt_path(record)
    assert_response :success
    assert_select "main", text: /Sample warehouse/
    assert_select "main", text: /Sample item/
    get stock_balances_path
    assert_response :success
    assert_select "tbody", text: /ngừng hoạt động/
    source = stock_query.stock_source(actor: @buyer, id: @second.id)
    assert_empty source[:warehouses]
    assert_empty source[:options].fetch(@second.lines.first.id)
  end
  test "unit mismatch and case mismatch are rejected and not offered" do
    [ "kg", "CÁI" ].each_with_index do |unit, i|
      item = stock_catalog(@buyer, :item, code: "WRONG#{i}", unit: unit)
      assert_raises(@invalid) { post_stock(@buyer, @first, @warehouse, item) }
      assert_not_includes stock_query.stock_source(actor: @buyer, id: @first.id)[:options].fetch(@first.lines.first.id).map(&:last), item.id
    end
    assert_empty balances(@buyer)[:records]
  end
  test "catalog code unit company immutable and edits use optimistic version" do
    assert_raises(ActiveRecord::RecordInvalid) { catalog_update(@buyer, @item, :item, code: "OTHER") }
    assert_raises(ActiveRecord::RecordInvalid) { catalog_update(@buyer, @item, :item, unit: "kg") }
    record = catalog_update(@buyer, @item, :item, name: "Updated name")
    assert_equal 1, record.lock_version
    assert_raises(ActiveRecord::StaleObjectError) do
      purchase_commands::SaveStockCatalog.new.call(actor: @buyer, kind: :item, id: @item.id, lock_version: 0, attributes: { code: @item.code, name: "Old", unit: "cái", status: "active" })
    end
  end
  test "foreign receipt warehouse item and URL access stay company scoped" do
    company = Company.create!(code: "STOCK#{SecureRandom.hex(4).upcase}", name: "Company two sample")
    buyer = make_user(:admin, company: company)
    foreign_warehouse = stock_catalog(buyer, :warehouse)
    foreign_item = stock_catalog(buyer, :item)
    foreign_receipt = receive_order(buyer, receipt_order(make_user(:employee, company: company), buyer))
    assert_raises(ActiveRecord::RecordNotFound) { post_stock(@buyer, foreign_receipt, @warehouse, @item) }
    assert_raises(ActiveRecord::RecordNotFound) { post_stock(@buyer, @first, foreign_warehouse, @item) }
    assert_raises(ActiveRecord::RecordNotFound) { post_stock(@buyer, @first, @warehouse, foreign_item) }
    record = post_stock(@buyer, @first, @warehouse, @item)
    assert_raises(ActiveRecord::RecordNotFound) { stock_query.find_stock_receipt!(actor: buyer, id: record.id) }
    assert_empty balances(buyer)[:records]
    purchase_login(buyer)
    get stock_receipt_path(record)
    assert_response :not_found
    get new_stock_receipt_path(goods_receipt_id: @first.id)
    assert_response :not_found
    get edit_inventory_item_path(@item)
    assert_response :not_found
    get stock_balances_path(warehouse_id: @warehouse.id)
    assert_select "tbody tr", count: 0
  end
  test "two companies each receive four plus six and retain independent queues and balances" do
    other = Company.create!(code: "TWOLEDGER#{SecureRandom.hex(4).upcase}", name: "Second ledger sample")
    buyer = make_user(:admin, company: other)
    order = receipt_order(make_user(:employee, company: other), buyer)
    first = receive_order(buyer, order)
    second = receive_order(buyer, order, receiving_attributes(order, quantity: "6"))
    warehouse = stock_catalog(buyer, :warehouse)
    item = stock_catalog(buyer, :item)
    own_entry = post_stock(@buyer, @first, @warehouse, @item)
    purchase_login(@buyer)
    get root_path
    assert_select "a[data-metric='pending_stock'] strong", text: "1"
    purchase_login(buyer)
    get root_path
    assert_select "a[data-metric='pending_stock'] strong", text: "2"
    get pending_stock_receipts_path
    assert_select "tbody tr", count: 2
    assert_not_includes response.body, @second.code
    foreign_entry = post_stock(buyer, first, warehouse, item)
    assert_equal BigDecimal("4"), balances(buyer)[:records].first[:quantity]
    post_stock(buyer, second, warehouse, item)
    assert_equal BigDecimal("10"), balances(buyer)[:records].first[:quantity]
    assert_equal BigDecimal("4"), balances(@buyer)[:records].first[:quantity]
    get stock_receipt_path(own_entry)
    assert_response :not_found
    purchase_login(@buyer)
    get stock_receipt_path(foreign_entry)
    assert_response :not_found
    post_stock(@buyer, @second, @warehouse, @item)
    assert_equal BigDecimal("10"), balances(@buyer)[:records].first[:quantity]
    assert_equal 1, balances(@buyer)[:count]
    assert_equal 1, balances(buyer)[:count]
  end
  test "anonymous and missing CSRF token cannot post a stock movement" do
    attrs = stock_attributes(@first, @warehouse, @item).merge(goods_receipt_id: @first.id)
    post stock_receipts_path, params: { stock_receipt: attrs }
    assert_response :redirect
    assert_equal 0, StockReceipt.count
    purchase_login(@buyer)
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    assert_no_difference("StockMovement.count") { post stock_receipts_path, params: { stock_receipt: attrs } }
    assert_response :unprocessable_content
  ensure
    ActionController::Base.allow_forgery_protection = previous unless previous.nil?
  end
  test "unrecorded receipts cannot post even when the source exists" do
    receipt = GoodsReceipt.create!(company_id: @buyer.company_id, purchase_order: @order, received_by: @buyer, code: "GR-UNRECORDED", received_on: Date.current, idempotency_key: SecureRandom.uuid, content_digest: "a" * 64)
    assert_raises(@conflict) { post_stock(@buyer, receipt, @warehouse, @item, attributes: stock_attributes(@first, @warehouse, @item)) }
  end
  test "revoked post grant denies new writes but replay remains read only with current view grant" do
    record = post_stock(@buyer, @first, @warehouse, @item)
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.receipts.post"), granted: false)
    assert_raises(Pundit::NotAuthorizedError) { post_stock(@buyer, @second, @warehouse, @item) }
    assert_no_difference("StockMovement.count") { assert_equal record.id, post_stock(@buyer, @first, @warehouse, @item).id }
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.receipts.read"), granted: false)
    assert_raises(Pundit::NotAuthorizedError) { post_stock(@buyer, @first, @warehouse, @item) }
    purchase_login(@buyer)
    get stock_receipt_path(record)
    assert_response :forbidden
  end
  test "journal failures after movements are written roll back header ledger and pending queue" do
    [ AuditLog, OutboxEvent ].each do |model|
      original = model.method(:create!)
      calls = 0
      callback = lambda do |**args|
        calls += 1
        if calls == 2
          assert_equal BigDecimal("4"), StockMovement.where(goods_receipt_id: @first.id).sum(:quantity)
          raise "Unavailable final stock journal"
        end
        original.call(**args)
      end
      assert_no_difference([ "StockReceipt.count", "StockMovement.count", "AuditLog.count", "OutboxEvent.count" ]) do
        model.stub(:create!, callback) { assert_raises(RuntimeError) { post_stock(@buyer, @first, @warehouse, @item) } }
      end
      assert_empty balances(@buyer)[:records]
      assert_equal 2, stock_query.pending_stock_workspace(actor: @buyer, filters: { page: 1 })[:count]
    end
  end
  test "KPI pending queue source links and ledger filter match actual posting" do
    purchase_login(@buyer)
    get root_path
    assert_select "a[data-metric='pending_stock'][href=?] strong", pending_stock_receipts_path, text: "2"
    get pending_stock_receipts_path
    assert_select "tbody tr", count: 2
    assert_select "a[href=?]", new_stock_receipt_path(goods_receipt_id: @first.id)
    get goods_receipt_path(@first)
    assert_select "a[href=?]", new_stock_receipt_path(goods_receipt_id: @first.id), text: "Nhập kho"
    get new_stock_receipt_path(goods_receipt_id: @first.id)
    assert_response :success
    assert_select "select[name='stock_receipt[warehouse_id]']"
    assert_select "input[name*='quantity']", count: 0
    attrs = stock_attributes(@first, @warehouse, @item).merge(goods_receipt_id: @first.id)
    attrs[:items].first["quantity"] = "999"
    post stock_receipts_path, params: { stock_receipt: attrs }
    record = StockReceipt.last
    assert_redirected_to stock_receipt_path(record)
    follow_redirect!
    assert_select "a[href=?]", goods_receipt_path(@first)
    assert_select "a[href=?]", purchase_order_path(@order)
    assert_select "a[href=?]", purchase_request_path(@order.purchase_request_id)
    assert_equal BigDecimal("4"), record.movements.first.quantity
    get goods_receipt_path(@first)
    assert_select "a[href=?]", stock_receipt_path(record), text: "Xem phiếu nhập"
    get root_path
    assert_select "a[data-metric='pending_stock'] strong", text: "1"
    post_stock(@buyer, @second, @warehouse, @item)
    get pending_stock_receipts_path
    assert_select "tbody tr", count: 0
    get root_path
    assert_select "a[data-metric='pending_stock'] strong", text: "0"
    get stock_balances_path(warehouse_id: @warehouse.id)
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /10.0/
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.receipts.post"), granted: false)
    get root_path
    assert_select "a[data-metric='pending_stock']", count: 0
    get pending_stock_receipts_path
    assert_response :forbidden
  end
  test "catalog HTTP CRUD validation options search and scoped permissions work" do
    purchase_login(@buyer)
    get new_inventory_warehouse_path
    assert_response :success
    post inventory_warehouses_path, params: { inventory_catalog: { code: "MAIN2", name: "Kho hai", status: "active" } }
    assert_redirected_to inventory_warehouses_path
    get inventory_items_path(q: @item.code)
    assert_select "tbody tr", count: 1
    get edit_inventory_item_path(@item)
    assert_select "input[name='inventory_catalog[unit]'][readonly]"
    patch inventory_item_path(@item), params: { lock_version: 0, inventory_catalog: { code: @item.code, name: "", unit: "cái", status: "active" } }
    assert_response :unprocessable_content
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.catalog.read"), granted: false)
    assert stock_query.stock_source(actor: @buyer, id: @first.id, item_search: @item.code)[:options].fetch(@first.lines.first.id).any?
    get inventory_items_path
    assert_response :forbidden
    purchase_login(@maker)
    get new_stock_receipt_path(goods_receipt_id: @first.id)
    assert_response :forbidden
  end
  test "stock metadata realtime requires current stock or catalog read grants" do
    admin = make_user(:admin)
    %w[warehouse.created stock_item.updated stock_receipt.updated].each do |type|
      assert Hrm::RealtimeAuthorization.allowed?(actor: admin, message: { type: type, id: 1 })
      assert_not Hrm::RealtimeAuthorization.allowed?(actor: @maker, message: { type: type, id: 1 })
    end
    admin.user_permissions.create!(permission: Permission.find_by!(key: "inventory.receipts.read"), granted: false)
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: admin, message: { type: "stock_receipt.updated", id: 1 })
  end
  test "MySQL guards prevent partial seal quantity forgery identity edits and ledger mutation" do
    assert_raises(ActiveRecord::StatementInvalid) do
      StockReceipt.transaction(requires_new: true) do
        header = StockReceipt.create!(company_id: @buyer.company_id, goods_receipt: @first, warehouse: @warehouse, posted_by: @buyer, code: "IN-EMPTY", mapping_digest: "b" * 64, warehouse_code_snapshot: @warehouse.code, warehouse_name_snapshot: @warehouse.name)
        header.update!(status: "posted", posted_at: Time.current)
      end
    end
    record = post_stock(@buyer, @first, @warehouse, @item)
    # rubocop:disable Rails/SkipsModelValidations -- Prove immutable stock ledger/catalog identity MySQL triggers against SQL bypass.
    assert_raises(ActiveRecord::StatementInvalid) { record.update_columns(warehouse_id: @warehouse.id, posted_at: Time.current) }
    assert_raises(ActiveRecord::StatementInvalid) { record.movements.first.update_columns(quantity: 999) }
    assert_raises(ActiveRecord::StatementInvalid) { StockReceipt.where(id: record.id).delete_all }
    assert_raises(ActiveRecord::StatementInvalid) { record.movements.delete_all }
    assert_raises(ActiveRecord::StatementInvalid) { @item.update_columns(unit: "kg") }
    assert_raises(ActiveRecord::StatementInvalid) { @warehouse.update_columns(code: "OTHER") }
    # rubocop:enable Rails/SkipsModelValidations
    assert_equal BigDecimal("4"), balances(@buyer)[:records].first[:quantity]
  end
end
