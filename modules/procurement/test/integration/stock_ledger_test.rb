require "test_helper"
require_relative "../support/stock_fixtures"
class StockLedgerTest < ActionDispatch::IntegrationTest
  include StockFixtures
  def setup
    @buyer = make_user(:manager)
    order = receipt_order(make_user(:employee), @buyer)
    @warehouse = stock_catalog(@buyer, :warehouse)
    @item = stock_catalog(@buyer, :item)
    @entry = post_stock(@buyer, receive_order(@buyer, order), @warehouse, @item)
    post_stock(@buyer, receive_order(@buyer, order, receiving_attributes(order, quantity: "6")), @warehouse, @item)
  end
  def ledger(**filters)
    HrmProcurement::Application::Queries::StockLedger.new.call(actor: @buyer, warehouse_id: @warehouse.id, stock_item_id: @item.id, **filters)
  end
  test "balance drills into exact posted pair and preserves filters through empty pages" do
    purchase_login(@buyer)
    get stock_balances_path(warehouse_id: @warehouse.id)
    target = stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: @item.id)
    assert_select "a[href=?]", target, text: "10.0"
    get target
    assert_response :success
    assert_select ".stock-ledger-scroll[tabindex='0'][role='region'][aria-label='Các dòng biến động kho']"
    assert_select "tbody tr", count: 2
    assert_select "a[href=?]", stock_receipt_path(@entry)
    assert_equal BigDecimal("10"), ledger[:quantity]
    assert_equal 2, ledger[:count]
    assert_empty ledger(page: "2")[:records]
    assert_equal BigDecimal("10"), ledger(page: "2")[:quantity]
    get stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: @item.id, page: 2)
    assert_select "a[href=?]", stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: @item.id, page: 1), text: "Trang trước"
  end
  test "valid empty pair is zero and foreign or malformed identifiers fail closed" do
    unused = stock_catalog(@buyer, :item, code: "EMPTY")
    repository = stock_query
    result = repository.stock_ledger(actor: @buyer, filters: { warehouse_id: @warehouse.id, stock_item_id: unused.id, page: 1 })
    assert_equal 0, result[:count]
    assert_equal 0, result[:quantity]
    other = Company.create!(name: "Other ledger company", code: "LEDGEROTHER")
    foreign_actor = make_user(:admin, company: other)
    foreign = stock_catalog(foreign_actor, :warehouse)
    foreign_item = stock_catalog(foreign_actor, :item)
    foreign_order = receipt_order(make_user(:employee, company: other), foreign_actor)
    foreign_entry = post_stock(foreign_actor, receive_order(foreign_actor, foreign_order), foreign, foreign_item)
    purchase_login(@buyer)
    [ foreign.id, [ @warehouse.id ], "1 OR 1=1", nil ].each do |id|
      get stock_ledger_path, params: { warehouse_id: id, stock_item_id: @item.id }
      assert_response :not_found
    end
    get stock_ledger_path, params: { warehouse_id: @warehouse.id, stock_item_id: [ @item.id ] }
    assert_response :not_found
    get stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: foreign_item.id)
    assert_response :not_found
    get stock_receipt_path(foreign_entry)
    assert_response :not_found
  end
  test "receipt read and ledger read are distinct current grants" do
    purchase_login(@buyer)
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.receipts.read"), granted: false)
    get stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: @item.id)
    assert_response :success
    assert_select "a[href=?]", stock_receipt_path(@entry), count: 0
    get stock_receipt_path(@entry)
    assert_response :forbidden
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.balances.read"), granted: false)
    get stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: @item.id)
    assert_response :forbidden
    assert_raises(Pundit::NotAuthorizedError) { ledger }
  end
  test "real second page retains pair and total without including another item or warehouse" do
    attrs = purchase_attributes.merge(items: Array.new(26) { |i| { description: "Line #{i}", quantity: "1", unit: "cái", estimated_unit_price: "100" } })
    order = issue_order(@buyer, create_order(@buyer, approved_source(make_user(:employee), @buyer, attributes: attrs), supplier_for(@buyer, code: "PAGED")))
    receipt = receive_order(@buyer, order, { idempotency_key: SecureRandom.uuid, received_on: Date.current.iso8601,
      items: order.lines.map { |line| { "purchase_order_line_id" => line.id.to_s, "quantity" => "1" } } })
    item = stock_catalog(@buyer, :item, code: "PAGED")
    post_stock(@buyer, receipt, @warehouse, item)
    filters = { warehouse_id: @warehouse.id, stock_item_id: item.id }
    purchase_login(@buyer)
    get stock_ledger_path(filters)
    assert_response :success
    assert_select "tbody tr", count: 25
    assert_select "tbody", text: /PAGED/
    assert_select "tbody", text: /SKU001/, count: 0
    assert_select ".panel strong", text: "26.0 cái"
    next_path = stock_ledger_path(filters.merge(page: 2))
    assert_select "a[href=?]", next_path, text: "Trang tiếp"
    get next_path
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select ".panel strong", text: "26.0 cái"
    assert_select "a[href=?]", stock_ledger_path(filters.merge(page: 1)), text: "Trang trước"
    assert_select "a", text: "Trang tiếp", count: 0
  end
end
