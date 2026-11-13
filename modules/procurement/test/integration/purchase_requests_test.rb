require "test_helper"
require "minitest/mock"
require_relative "../support/procurement_fixtures"

class PurchaseRequestsTest < ActionDispatch::IntegrationTest
  include ProcurementFixtures
  def setup
    @maker = make_user(:employee)
    @checker = make_user(:manager)
    @other_company = Company.create!(code: "BUY#{SecureRandom.hex(4).upcase}", name: "Second purchase company")
    @outsider = make_user(:employee, company: @other_company)
  end
  test "server computes exact VND line rounding and draft identity without trusting supplied totals" do
    attributes = purchase_attributes.merge(company_id: @other_company.id, created_by_id: @outsider.id, status: "approved", currency: "USD", estimated_total: "1")
    record = purchase_commands::CreateRequest.new.call(actor: @maker, attributes: attributes)
    assert_equal @maker.company_id, record.company_id
    assert_equal @maker.id, record.created_by_id
    assert_equal "VND", record.currency
    assert_equal "draft", record.status
    assert_equal BigDecimal("1126"), record.estimated_total
    assert_equal [ BigDecimal("1125"), BigDecimal("1") ], record.lines.map(&:line_total)
    assert_equal [ "created" ], record.events.pluck(:action)
    assert_not_includes record.read_attribute_before_type_cast(:purpose), attributes[:purpose]
    assert_equal @maker.id, record.events.first.actor_id
  end
  test "draft editing is owner only versioned and submitted content is immutable in MySQL" do
    record = create_purchase(@maker)
    updated = purchase_commands::UpdateRequest.new.call(actor: @maker, id: record.id, attributes: purchase_attributes(title: "Updated need"), lock_version: 0)
    assert_equal "Updated need", updated.title
    assert_equal 1, updated.lock_version
    assert_raises(ActiveRecord::StaleObjectError) { purchase_commands::UpdateRequest.new.call(actor: @maker, id: record.id, attributes: purchase_attributes, lock_version: 0) }
    assert_raises(Pundit::NotAuthorizedError) { purchase_commands::UpdateRequest.new.call(actor: @checker, id: record.id, attributes: purchase_attributes, lock_version: updated.lock_version) }
    submitted = submit_purchase(@maker, updated)
    assert_raises(HrmProcurement::Domain::Services::RequestConflict) { purchase_commands::UpdateRequest.new.call(actor: @maker, id: record.id, attributes: purchase_attributes, lock_version: submitted.lock_version) }
    # rubocop:disable Rails/SkipsModelValidations -- Prove MySQL guards reject writes that bypass model validation.
    assert_raises(ActiveRecord::StatementInvalid) { PurchaseRequest.where(id: record.id).update_all(title: "Forged") }
    # rubocop:enable Rails/SkipsModelValidations
    # rubocop:disable Rails/SkipsModelValidations -- Prove MySQL guards reject writes that bypass model validation.
    assert_raises(ActiveRecord::StatementInvalid) { PurchaseRequestLine.where(purchase_request_id: record.id).update_all(description: "Changed after submit") }
    # rubocop:enable Rails/SkipsModelValidations
    assert_raises(ActiveRecord::StatementInvalid) { PurchaseRequestLine.where(purchase_request_id: record.id).delete_all }
    assert_equal "Updated need", submitted.reload.title
    assert_equal [ "created", "updated", "submitted" ], submitted.events.order(:version).pluck(:action)
  end
  test "maker checker and immutable decisions record actor time and encrypted rejection reason" do
    own = create_purchase(@checker)
    own = submit_purchase(@checker, own)
    assert_raises(Pundit::NotAuthorizedError) { decide_purchase(@checker, own) }
    record = submit_purchase(@maker, create_purchase(@maker))
    assert_raises(HrmProcurement::Domain::Services::RequestContent::Invalid) { decide_purchase(@checker, record, decision: "rejected", reason: " ") }
    assert_equal "submitted", record.reload.status
    assert_equal 2, record.events.count
    rejected = decide_purchase(@checker, record, decision: "rejected", reason: "Need another quote")
    assert_equal "rejected", rejected.status
    assert_equal @checker.id, rejected.reviewed_by_id
    assert_operator rejected.reviewed_at, :>=, rejected.submitted_at
    assert_equal "Need another quote", rejected.events.order(:version).last.note
    assert_not_includes rejected.events.order(:version).last.read_attribute_before_type_cast(:note), "Need another quote"
    assert_raises(ActiveRecord::StaleObjectError) { decide_purchase(@checker, rejected, version: 1) }
    assert_equal 1, rejected.events.where(action: "rejected").count
  end
  test "audit and outbox failure roll back the decision and history" do
    record = submit_purchase(@maker, create_purchase(@maker))
    before = [ PurchaseRequestEvent.count, AuditLog.count, OutboxEvent.count ]
    [ AuditLog, OutboxEvent ].each do |model|
      model.stub(:create!, ->(**_) { raise "Unavailable audit/outbox" }) do
        assert_raises(RuntimeError) { decide_purchase(@checker, record) }
      end
      assert_equal "submitted", record.reload.status
      assert_equal before, [ PurchaseRequestEvent.count, AuditLog.count, OutboxEvent.count ]
    end
  end
  test "cross-company IDs unavailable grants and forged ownership fail closed" do
    record = submit_purchase(@maker, create_purchase(@maker))
    assert_raises(ActiveRecord::RecordNotFound) { HrmProcurement::Application::Queries::FindRequest.new.call(actor: @outsider, id: record.id) }
    outsider_checker = make_user(:manager, company: @other_company)
    assert_raises(ActiveRecord::RecordNotFound) { decide_purchase(outsider_checker, record) }
    @checker.user_permissions.create!(permission: Permission.find_by!(key: "procurement.requests.review"), granted: false)
    assert_raises(Pundit::NotAuthorizedError) { decide_purchase(@checker, record) }
    purchase_login(@outsider)
    get purchase_request_path(record)
    assert_response :not_found
    purchase_login(@maker)
    post decide_purchase_request_path(record), params: { decision: "approved", lock_version: 1, company_id: @other_company.id }
    assert_response :forbidden
    assert_equal "submitted", record.reload.status
  end
  test "HTTP create submit dashboard source approval and history keep filters and exclude other companies" do
    foreign = submit_purchase(@outsider, create_purchase(@outsider))
    own = submit_purchase(@checker, create_purchase(@checker))
    purchase_login(@maker)
    get new_purchase_request_path
    assert_response :success
    assert_select "[data-add-purchase-line]"
    attributes = purchase_attributes(title: "Office chairs").merge(company_id: @other_company.id, estimated_total: 1, status: "approved")
    post purchase_requests_path, params: { purchase_request: attributes }
    assert_equal I18n.t("procurement.notices.created", locale: :vi), flash[:notice]
    record = PurchaseRequest.where(created_by_id: @maker.id).order(:id).last
    assert_redirected_to purchase_request_path(record, page: 1)
    assert_equal BigDecimal("1126"), record.estimated_total
    post submit_purchase_request_path(record), params: { lock_version: record.lock_version }
    assert_response :redirect
    get "/"
    assert_select ".metric-card[data-metric='purchases']", count: 0
    purchase_login(@checker)
    get "/"
    assert_select ".metric-card[data-metric='purchases'] strong", text: "1"
    assert_select ".dashboard-widgets a[href^='/procurement/requests/#{record.id}?']", count: 1
    assert_select ".dashboard-widgets a[href^='/procurement/requests/#{foreign.id}?']", count: 0
    assert_select ".dashboard-widgets a[href^='/procurement/requests/#{own.id}?']", count: 0
    source = css_select(".metric-card[data-metric='purchases']").first["href"]
    get source
    assert_response :success
    assert_select "tbody tr", count: 1
    detail = css_select("tbody a").first["href"]
    get detail
    assert_response :success
    assert_select "a[href*='status=submitted'][href*='view=review']", text: "← Danh sách đã lọc"
    assert_match(/no-store/, response.headers["Cache-Control"])
    post decide_purchase_request_path(record), params: { decision: "approved", lock_version: record.reload.lock_version }
    assert_response :redirect
    get purchase_request_path(record)
    assert_response :success
    assert_select ".purchase-history li", count: 3
    assert_equal "approved", record.reload.status
    get "/"
    assert_select ".metric-card[data-metric='purchases'] strong", text: "0"
    get css_select(".metric-card[data-metric='purchases']").first["href"]
    assert_select "tbody tr", count: 0
    assert_select ".empty", text: /Không có phiếu/
  end
  test "revoked review grant removes dashboard values and direct queue access" do
    submit_purchase(@maker, create_purchase(@maker))
    purchase_login(@checker)
    get "/"
    assert_select ".metric-card[data-metric='purchases'] strong", text: "1"
    @checker.user_permissions.create!(permission: Permission.find_by!(key: "procurement.requests.review"), granted: false)
    get "/"
    assert_select ".metric-card[data-metric='purchases']", count: 0
    assert_select "nav a[href*='view=review']", count: 0
    get purchase_requests_path(view: "review", status: "submitted")
    assert_response :forbidden
  end
  test "search status and pagination stay on mine scope and detail back link" do
    26.times { create_purchase(@maker, title: "Office order") }
    create_purchase(@maker, title: "Not matching")
    create_purchase(@outsider, title: "Office order")
    purchase_login(@maker)
    get purchase_requests_path, params: { q: "Office", status: "draft", view: "mine" }
    assert_select "tbody tr", count: 25
    detail = css_select("tbody a").first["href"]
    next_page = css_select(".pagination a").find { |node| node.text.include?("Trang tiếp") }["href"]
    get next_page
    assert_select "tbody tr", count: 1
    get detail
    back = css_select("a").find { |node| node.text.include?("Danh sách đã lọc") }["href"]
    assert_includes back, "q=Office"
    assert_includes back, "status=draft"
    assert_includes back, "view=mine"
  end
  test "malformed inputs decimal overflow permissions and CSRF never create partial requests" do
    purchase_login(@maker)
    attrs = purchase_attributes
    attrs[:items].first["quantity"] = "1.0001"
    assert_no_difference [ "PurchaseRequest.count", "PurchaseRequestLine.count", "PurchaseRequestEvent.count" ] do
      post purchase_requests_path, params: { purchase_request: attrs }
      assert_response :unprocessable_entity
      post purchase_requests_path, params: { purchase_request: purchase_attributes.merge(items: Array.new(51) { purchase_attributes[:items].first }) }
      assert_response :unprocessable_entity
    end
    get purchase_requests_path, params: { status: [ "submitted" ] }
    assert_response :not_found
    get purchase_requests_path, params: { page: { bad: "1" } }
    assert_response :not_found
    record = create_purchase(@maker)
    old = ActionController::Base.allow_forgery_protection
    begin
      ActionController::Base.allow_forgery_protection = true
      post submit_purchase_request_path(record), params: { lock_version: record.lock_version }
      assert_response :unprocessable_entity
      assert_equal "draft", record.reload.status
    ensure
      ActionController::Base.allow_forgery_protection = old
    end
  end
  test "database rejects incorrect line totals cross-company actors and line moves after submission" do
    draft = create_purchase(@maker)
    submitted = submit_purchase(@maker, create_purchase(@maker))
    # rubocop:disable Rails/SkipsModelValidations -- Prove MySQL guards reject writes that bypass model validation.
    assert_raises(ActiveRecord::StatementInvalid) { PurchaseRequestLine.where(id: draft.lines.first.id).update_all(purchase_request_id: submitted.id) }
    # rubocop:enable Rails/SkipsModelValidations
    # rubocop:disable Rails/SkipsModelValidations -- Prove MySQL guards reject writes that bypass model validation.
    assert_raises(ActiveRecord::StatementInvalid) { PurchaseRequestLine.where(id: draft.lines.first.id).update_all(line_total: 9) }
    # rubocop:enable Rails/SkipsModelValidations
    # rubocop:disable Rails/SkipsModelValidations -- Prove MySQL guards reject writes that bypass model validation.
    assert_raises(ActiveRecord::StatementInvalid) { PurchaseRequest.where(id: draft.id).update_all(created_by_id: @outsider.id) }
    # rubocop:enable Rails/SkipsModelValidations
    # rubocop:disable Rails/SkipsModelValidations -- Prove MySQL guards reject writes that bypass model validation.
    assert_raises(ActiveRecord::StatementInvalid) { PurchaseRequest.where(id: draft.id).update_all(estimated_total: 1, status: "submitted", submitted_at: Time.current) }
    # rubocop:enable Rails/SkipsModelValidations
    assert_equal "draft", draft.reload.status
  end
end
