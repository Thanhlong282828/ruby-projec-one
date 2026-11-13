require "test_helper"
require "minitest/mock"
require_relative "../support/order_fixtures"

class PurchaseOrdersTest < ActionDispatch::IntegrationTest
  include OrderFixtures
  def setup
    @maker = make_user(:employee)
    @buyer = make_user(:manager)
    @other = Company.create!(code: "PO#{SecureRandom.hex(4).upcase}", name: "Other PO sample")
    @foreign_buyer = make_user(:manager, company: @other)
    @foreign_maker = make_user(:employee, company: @other)
    @source = approved_source(@maker, @buyer)
    @supplier = supplier_for(@buyer)
  end
  test "supplier catalog is tenant scoped versioned and inactive options excluded" do
    foreign = supplier_for(@foreign_buyer)
    assert_equal @supplier.code, foreign.code
    changed = purchase_commands::SaveSupplier.new.call(actor: @buyer, id: @supplier.id, lock_version: 0, attributes: { code: "RENAMED", name: "Updated supplier", status: "inactive" })
    assert_equal 1, changed.lock_version
    assert_raises(ActiveRecord::StaleObjectError) { purchase_commands::SaveSupplier.new.call(actor: @buyer, id: @supplier.id, lock_version: 0, attributes: { code: "REPLAY", name: "Old input", status: "active" }) }
    source = HrmProcurement::Application::Queries::OrderSource.new.call(actor: @buyer, id: @source.id)
    assert_empty source[:suppliers]
    assert_raises(ActiveRecord::RecordNotFound) { create_order(@buyer, @source, changed) }
    assert_raises(ActiveRecord::RecordNotFound) { create_order(@buyer, @source, foreign) }
    purchase_login(@buyer)
    get edit_procurement_supplier_path(foreign)
    assert_response :not_found
    get procurement_suppliers_path(status: "inactive")
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /Updated supplier/
    purchase_login(@maker)
    get procurement_suppliers_path
    assert_response :forbidden
  end
  test "approved source is snapshotted once and replay never replaces supplier or dates" do
    record = create_order(@buyer, @source, @supplier)
    assert_equal BigDecimal("1126"), record.ordered_total
    assert_equal @source.estimated_total, record.request_total_snapshot
    assert_equal @source.lines.pluck(:id), record.lines.map(&:source_line_id)
    assert_equal @source.lines.pluck(:quantity), record.lines.map(&:quantity)
    assert_equal [ "created" ], record.events.pluck(:action)
    alternate = supplier_for(@buyer, code: "ALT")
    replay = create_order(@buyer, @source, alternate, date: "2027-01-01")
    assert_equal record.id, replay.id
    assert_equal @supplier.id, replay.supplier_id
    assert_equal Date.new(2026, 12, 1), replay.expected_on
    assert_equal 1, PurchaseOrder.where(purchase_request_id: @source.id).count
    assert_equal 1, record.events.count
    duplicate = record.attributes.except("id").merge("code" => "PO-DUPLICATE")
    # rubocop:disable Rails/SkipsModelValidations -- Prove the unique source constraint rejects direct SQL duplicate creation.
    assert_raises(ActiveRecord::RecordNotUnique) { PurchaseOrder.insert_all!([ duplicate ]) }
    # rubocop:enable Rails/SkipsModelValidations
  end
  test "unapproved cross-company and unreadable sources cannot create orders" do
    draft = create_purchase(@maker)
    purchase_login(@maker)
    get edit_purchase_request_path(draft)
    assert_response :success
    assert_select "input[name='purchase_request[items][0][estimated_unit_price]'][value='1000']"
    assert_raises(HrmProcurement::Domain::Services::RequestConflict) { create_order(@buyer, draft, @supplier) }
    foreign = approved_source(@foreign_maker, @foreign_buyer)
    assert_raises(ActiveRecord::RecordNotFound) { create_order(@buyer, foreign, @supplier) }
    assert_raises(Pundit::NotAuthorizedError) { create_order(@maker, @source, @supplier) }
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "procurement.requests.read_all"), granted: false)
    assert_raises(ActiveRecord::RecordNotFound) { create_order(@buyer, @source, @supplier) }
    assert_equal 0, PurchaseOrder.count
  end
  test "exact prices immutable quantities reason and source totals survive edits and issue" do
    record = create_order(@buyer, @source, @supplier)
    changed = update_order(@buyer, record, order_attributes(record, prices: [ "2000", "1500" ]))
    assert_equal BigDecimal("2252"), changed.ordered_total
    assert_equal BigDecimal("1126"), changed.request_total_snapshot
    assert_raises(HrmProcurement::Domain::Services::RequestContent::Invalid) { issue_order(@buyer, changed) }
    changed = update_order(@buyer, changed, order_attributes(changed, reason: "New supplier quotation"))
    assert_not_includes changed.read_attribute_before_type_cast(:price_change_reason), "New supplier quotation"
    issued = issue_order(@buyer, changed)
    assert_equal "issued", issued.status
    assert_equal @buyer.id, issued.issued_by_id
    assert issued.issued_at
    assert_equal [ "created", "updated", "updated", "issued" ], issued.events.order(:version).pluck(:action)
    assert_raises(ActiveRecord::StaleObjectError) { issue_order(@buyer, issued, version: 0) }
    assert_raises(HrmProcurement::Domain::Services::RequestConflict) { update_order(@buyer, issued, order_attributes(issued)) }
    assert_equal BigDecimal("1126"), @source.reload.estimated_total
  end
  test "offsetting price changes still require explanation even when total difference is zero" do
    attrs = purchase_attributes
    attrs[:items] = [ { "description" => "A", "quantity" => "1", "unit" => "piece", "estimated_unit_price" => "100" }, { "description" => "B", "quantity" => "1", "unit" => "piece", "estimated_unit_price" => "200" } ]
    source = approved_source(@maker, @buyer, attributes: attrs)
    record = create_order(@buyer, source, @supplier)
    record = update_order(@buyer, record, order_attributes(record, prices: [ "150", "150" ]))
    assert_equal record.request_total_snapshot, record.ordered_total
    assert_raises(HrmProcurement::Domain::Services::RequestContent::Invalid) { issue_order(@buyer, record) }
  end
  test "inactive or renamed suppliers preserve historical snapshot and block issue" do
    record = create_order(@buyer, @source, @supplier)
    purchase_commands::SaveSupplier.new.call(actor: @buyer, id: @supplier.id, lock_version: 0, attributes: { code: "NEWCODE", name: "New legal name", status: "inactive" })
    assert_raises(HrmProcurement::Domain::Services::RequestContent::Invalid) { issue_order(@buyer, record) }
    purchase_login(@buyer)
    get purchase_order_path(record)
    assert_response :success
    assert_select "main", text: /SAMPLE.*Sample supplier/
    assert_equal "Sample supplier", record.reload.supplier_name_snapshot
  end
  test "audit or outbox failure rolls back creation edits issue and history" do
    [ AuditLog, OutboxEvent ].each do |model|
      model.stub(:create!, ->(**_) { raise "Unavailable journal" }) do
        assert_no_difference [ "PurchaseOrder.count", "PurchaseOrderLine.count", "PurchaseOrderEvent.count" ] do
          assert_raises(RuntimeError) { create_order(@buyer, @source, @supplier) }
        end
      end
    end
    record = create_order(@buyer, @source, @supplier)
    [ AuditLog, OutboxEvent ].each do |model|
      counts = [ PurchaseOrderEvent.count, AuditLog.count, OutboxEvent.count ]
      model.stub(:create!, ->(**_) { raise "Unavailable journal" }) do
        assert_raises(RuntimeError) { update_order(@buyer, record, order_attributes(record, prices: [ "1001", "501" ], reason: "Sample change")) }
        assert_raises(RuntimeError) { issue_order(@buyer, record.reload) }
      end
      assert_equal [ "draft", BigDecimal("1126"), 0 ], record.reload.attributes.values_at("status", "ordered_total", "lock_version")
      assert_equal [ BigDecimal("1000"), BigDecimal("500") ], record.lines.reload.map(&:unit_price)
      assert_equal counts, [ PurchaseOrderEvent.count, AuditLog.count, OutboxEvent.count ]
    end
  end
  test "database protects snapshots quantities issued content and line source links" do
    record = create_order(@buyer, @source, @supplier)
    # rubocop:disable Rails/SkipsModelValidations -- Prove MySQL guards reject bypassing model and command validation.
    assert_raises(ActiveRecord::StatementInvalid) { record.lines.update_all(quantity: 2) }
    assert_raises(ActiveRecord::StatementInvalid) { record.lines.update_all(source_line_id: @source.lines.last.id) }
    assert_raises(ActiveRecord::StatementInvalid) { PurchaseOrder.where(id: record.id).update_all(supplier_name_snapshot: "Forged") }
    issue_order(@buyer, record)
    assert_raises(ActiveRecord::StatementInvalid) { record.lines.update_all(unit_price: 900, line_total: 900) }
    assert_raises(ActiveRecord::StatementInvalid) { PurchaseOrder.where(id: record.id).update_all(expected_on: Date.new(2030, 1, 1)) }
    # rubocop:enable Rails/SkipsModelValidations
    assert_raises(ActiveRecord::StatementInvalid) { record.lines.delete_all }
  end
  test "malformed prices source rows and optimistic version cannot alter drafts" do
    record = create_order(@buyer, @source, @supplier)
    [ "1.5", "1e3", "1000000000000", 1.2 ].each do |price|
      assert_raises(HrmProcurement::Domain::Services::RequestContent::Invalid) { update_order(@buyer, record, order_attributes(record, prices: [ price, "500" ])) }
    end
    attrs = order_attributes(record)
    attrs[:items][1]["source_line_id"] = attrs[:items][0]["source_line_id"]
    assert_raises(HrmProcurement::Domain::Services::RequestContent::Invalid) { update_order(@buyer, record, attrs) }
    assert_raises(ActiveRecord::StaleObjectError) { update_order(@buyer, record, order_attributes(record), version: nil) }
    assert_equal 0, record.reload.lock_version
  end
  test "revoked create issue read grants deny commands dashboard and direct URLs" do
    record = create_order(@buyer, @source, @supplier)
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "procurement.orders.issue"), granted: false)
    assert_raises(Pundit::NotAuthorizedError) { issue_order(@buyer, record) }
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "procurement.orders.create"), granted: false)
    assert_raises(Pundit::NotAuthorizedError) { create_order(@buyer, @source, @supplier) }
    purchase_login(@buyer)
    get "/"
    assert_select "[data-metric=awaiting_orders]", count: 0
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "procurement.orders.read"), granted: false)
    get purchase_order_path(record)
    assert_response :forbidden
    purchase_login(@foreign_buyer)
    get purchase_order_path(record)
    assert_response :not_found
  end
  test "HTTP supplier source KPI draft edit issue and backlinks follow real company scoped data" do
    foreign_source = approved_source(@foreign_maker, @foreign_buyer)
    purchase_login(@buyer)
    get "/"
    assert_select "[data-metric=awaiting_orders] strong", text: "1"
    source_path = css_select("[data-metric=awaiting_orders]").first["href"]
    get source_path
    assert_select "h1", text: "Phiếu đã duyệt chờ lập PO"
    assert_select "tbody tr", count: 1
    get css_select("tbody a").first["href"]
    assert_select "a", text: "Tạo đơn mua hàng"
    get new_purchase_order_path(purchase_request_id: @source.id)
    assert_select "select option", text: /Sample supplier/
    post purchase_orders_path, params: { purchase_order: { purchase_request_id: @source.id, supplier_id: @supplier.id, expected_on: "2026-12-01", ordered_total: 1, company_id: @other.id } }
    assert_response :redirect
    record = PurchaseOrder.find_by!(purchase_request_id: @source.id)
    get purchase_request_path(@source)
    assert_select "a[href='#{purchase_order_path(record)}']", text: "Xem đơn mua hàng"
    get "/"
    assert_select "[data-metric=awaiting_orders] strong", text: "0"
    get source_path
    assert_select "tbody tr", count: 0
    get purchase_order_path(record)
    assert_select "a[href='#{purchase_request_path(@source)}']"
    assert_select "[href='#{purchase_request_path(foreign_source)}']", count: 0
    assert_match(/no-store/, response.headers["Cache-Control"])
    get edit_purchase_order_path(record)
    assert_response :success
    assert_select "input[name='purchase_order[items][0][unit_price]'][value='1000']"
    patch purchase_order_path(record), params: { lock_version: 0, purchase_order: { expected_on: "bad", items: [] } }
    assert_response :unprocessable_entity
    assert_select "input[name='purchase_order[items][0][unit_price]'][value='1000']"
    patch purchase_order_path(record), params: { lock_version: 0, purchase_order: order_attributes(record, prices: [ "1001", "501" ], reason: "New quote") }
    assert_response :redirect
    post issue_purchase_order_path(record), params: { lock_version: record.reload.lock_version }
    assert_response :redirect
    get purchase_order_path(record)
    assert_select "#order-history li", count: 3
    assert_select "a", text: "Sửa PO nháp", count: 0
    get purchase_orders_path(status: "issued", q: record.code)
    assert_select "tbody tr", count: 1
    get purchase_orders_path(status: [ "issued" ])
    assert_response :not_found
  end
  test "supplier HTTP input and PO CSRF checks protect actual write actions" do
    purchase_login(@buyer)
    post procurement_suppliers_path, params: { supplier: { code: "WEB", name: "Web sample", status: "active", company_id: @other.id } }
    assert_response :redirect
    supplier = ProcurementSupplier.find_by!(company_id: @buyer.company_id, code: "WEB")
    patch procurement_supplier_path(supplier), params: { lock_version: 0, supplier: { code: "WEB", name: "Stopped", status: "inactive" } }
    assert_response :redirect
    assert_equal "inactive", supplier.reload.status
    record = create_order(@buyer, @source, @supplier)
    old = ActionController::Base.allow_forgery_protection
    begin
      ActionController::Base.allow_forgery_protection = true
      post issue_purchase_order_path(record), params: { lock_version: 0 }
      assert_response :unprocessable_entity
      assert_equal "draft", record.reload.status
    ensure
      ActionController::Base.allow_forgery_protection = old
    end
  end
  test "issued PO supplier snapshot remains visible after supplier is deactivated" do
    record = issue_order(@buyer, create_order(@buyer, @source, @supplier))
    purchase_commands::SaveSupplier.new.call(actor: @buyer, id: @supplier.id, lock_version: 0, attributes: { code: "STOPPED", name: "Renamed inactive", status: "inactive" })
    purchase_login(@buyer)
    get purchase_order_path(record)
    assert_response :success
    assert_select "main", text: /Sample supplier/
    assert_equal "issued", record.reload.status
    other_source = approved_source(@maker, @buyer)
    assert_raises(ActiveRecord::RecordNotFound) { create_order(@buyer, other_source, @supplier) }
  end
  test "PO search pagination and detail back links retain the same filters" do
    26.times do
      source = approved_source(@maker, @buyer)
      create_order(@buyer, source, @supplier)
    end
    purchase_login(@buyer)
    get purchase_orders_path(q: "Office", status: "draft")
    assert_select "tbody tr", count: 25
    detail = css_select("tbody a").first["href"]
    next_page = css_select(".pagination a").find { |node| node.text.include?("Trang tiếp") }["href"]
    get next_page
    assert_select "tbody tr", count: 1
    get detail
    back = css_select("a").find { |node| node.text.include?("Danh sách PO đã lọc") }["href"]
    assert_includes back, "q=Office"
    assert_includes back, "status=draft"
  end
  test "PO and supplier realtime metadata require their own revocable grants" do
    hr = make_user(:hr)
    assert Hrm::RealtimeAuthorization.allowed?(actor: hr, message: { type: "employee.created", id: 1 })
    %w[purchase_order.created procurement_supplier.updated purchase_request.updated].each do |type|
      assert_not Hrm::RealtimeAuthorization.allowed?(actor: hr, message: { type: type, id: 1 })
    end
    admin = make_user(:admin)
    assert Hrm::RealtimeAuthorization.allowed?(actor: admin, message: { type: "purchase_order.created", id: 1 })
    assert Hrm::RealtimeAuthorization.allowed?(actor: admin, message: { type: "procurement_supplier.updated", id: 1 })
    admin.user_permissions.create!(permission: Permission.find_by!(key: "procurement.orders.read"), granted: false)
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: admin, message: { type: "purchase_order.created", id: 1 })
    assert Hrm::RealtimeAuthorization.allowed?(actor: admin, message: { type: "procurement_supplier.updated", id: 1 })
    admin.user_permissions.create!(permission: Permission.find_by!(key: "realtime.read"), granted: false)
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: admin, message: { type: "procurement_supplier.updated", id: 1 })
  end
end
