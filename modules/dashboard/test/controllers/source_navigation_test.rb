require "test_helper"
class DashboardSourceNavigationTest < ActionDispatch::IntegrationTest
  def setup
    @admin = make_user(:admin)
    @employee = make_employee(full_name: "Visible employee")
    @other = Company.create!(code: "DASH#{SecureRandom.hex(3).upcase}", name: "Second dashboard company")
    @foreign = make_employee(make_user(company: @other), full_name: "Foreign employee")
    @period = Date.current.beginning_of_month
  end
  def login(actor = @admin)
    post "/session", params: { email: actor.email, password: "StrongPassword123!" }
    assert_response :redirect
  end
  def leave(employee, date = Date.current)
    employee.leave_requests.create!(starts_on: date, ends_on: date, reason: "Sample leave")
  end
  def onboarding(employee, actor)
    record = HrmOnboarding::Application::Commands::CreateCase.new.call(actor: actor, attributes: { employee_id: employee.id, start_date: Date.current.iso8601 })
    HrmOnboarding::Application::Commands::TransitionCase.new.call(actor: actor, id: record.id, status: "in_progress", lock_version: record.lock_version)
  end
  def card_source(key, expected)
    assert_select ".metric-card[data-metric='#{key}'] strong", text: expected.to_s
    css_select(".metric-card[data-metric='#{key}']").first["href"]
  end
  test "pending leave card and widget reach only pending records and the owned detail" do
    pending = leave(@employee)
    leave(@employee, Date.current + 1).update!(status: "rejected")
    foreign = leave(@foreign)
    login
    get "/"
    source = card_source("pending", 1)
    assert_equal "/leave_requests?status=pending", source
    assert_select ".dashboard-widgets a[href='/leave_requests/#{pending.id}']", count: 1
    assert_select ".dashboard-widgets form", count: 0
    get source
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "a[href='/leave_requests/#{pending.id}']", count: 1
    assert_select "select[name='status'] option[selected]", text: "Chờ duyệt"
    get "/leave_requests/#{pending.id}"
    assert_response :success
    assert_includes response.body, @employee.full_name
    get "/leave_requests/#{foreign.id}"
    assert_response :not_found
  end
  test "active employees open attendance and selected payroll period match source lists" do
    make_employee(status: "inactive")
    open_shift = @employee.attendances.create!(work_date: Date.current - 1, checked_in_at: 1.day.ago)
    @employee.attendances.create!(work_date: Date.current, checked_in_at: 2.hours.ago, checked_out_at: 1.hour.ago)
    @foreign.attendances.create!(work_date: Date.current, checked_in_at: 1.hour.ago)
    run = PayRun.create!(company: @admin.company, created_by: @admin, period: @period)
    PayRun.create!(company: @admin.company, created_by: @admin, period: @period.prev_month)
    foreign_run = PayRun.create!(company: @other, created_by: make_user(:admin, company: @other), period: @period)
    login
    get "/", params: { period: @period.strftime("%Y-%m") }
    sources = [ card_source("employees", 1), card_source("open", 1), card_source("drafts", 1) ]
    assert_select ".dashboard-widgets a[href='/attendances/#{open_shift.id}']"
    assert_select ".dashboard-widgets a[href='/pay_runs/#{run.id}']"
    sources.each do |source|
      get source
      assert_response :success
      assert_select "tbody tr", count: 1
    end
    assert_select "input[name='period'][value='#{@period.strftime('%Y-%m')}']"
    get "/attendances/#{open_shift.id}"
    assert_response :success
    get "/pay_runs/#{foreign_run.id}"
    assert_response :not_found
    get "/attendances/#{@foreign.attendances.first.id}"
    assert_response :not_found
  end
  test "onboarding state column record and next checklist links preserve owned source" do
    record = onboarding(@employee, @admin)
    foreign = onboarding(@foreign, make_user(:admin, company: @other))
    login
    get "/"
    source = card_source("onboarding", 1)
    assert_equal "/onboarding/cases?status=in_progress", source
    assert_select ".dashboard-onboarding a[href='/onboarding/cases/#{record.id}']"
    assert_select ".dashboard-onboarding .checklist-next[href^='/onboarding/cases/#{record.id}#checklist-']"
    assert_select ".dashboard-onboarding a[href='/onboarding/cases/#{foreign.id}']", count: 0
    get source
    assert_response :success
    assert_select ".onboarding-board > section", count: 1
    assert_select ".onboarding-card", count: 1
    get "/onboarding/cases/#{record.id}"
    assert_response :success
    record.checklist.each { |item| assert_select "li[id='checklist-#{item['code']}']" }
    get "/onboarding/cases/#{foreign.id}"
    assert_response :not_found
  end
  test "zero cards lead to empty scoped lists rather than unrelated records" do
    leave(@foreign)
    login
    get "/", params: { period: @period.next_month.strftime("%Y-%m") }
    sources = %w[pending open drafts onboarding].map { |key| card_source(key, 0) }
    sources.each do |source|
      get source
      assert_response :success
      assert_select "tbody tr", count: 0
      assert_select ".onboarding-card", count: 0
    end
  end
  test "employee scope and revoked grants hide both values and source links" do
    own = leave(@employee)
    leave(make_employee)
    login(@employee.user)
    get "/"
    card_source("pending", 1)
    assert_select ".metric-card[data-metric='drafts']", count: 0
    assert_select ".dashboard-widgets a[href='/leave_requests/#{own.id}']"
    @employee.user.user_permissions.create!(permission: Permission.find_by!(key: "leave.read"), granted: false)
    get "/"
    assert_response :success
    assert_select ".metric-card[data-metric='pending']", count: 0
    assert_select "a[href^='/leave_requests']", count: 0
    get "/leave_requests?status=pending"
    assert_response :forbidden
    get "/leave_requests/#{own.id}"
    assert_response :forbidden
  end
  test "company switch updates metrics and refuses old company detail URLs" do
    old = leave(@employee)
    2.times { |n| leave(@foreign, Date.current + n) }
    profile = User.create!(company: @other, principal_user: @admin, email: @admin.email, role: "admin")
    login
    get "/"
    card_source("pending", 1)
    post "/my/company-context", params: { membership_id: profile.id.to_s }
    assert_redirected_to "/"
    get "/"
    assert_response :success
    assert_select ".company-context-title strong", text: @other.name
    source = card_source("pending", 2)
    get source
    assert_select "tbody tr", count: 2
    get "/leave_requests/#{old.id}"
    assert_response :not_found
  end
  test "unsupported structured filters fail closed and company parameters cannot select tenant" do
    login
    [ [ "/leave_requests", { status: [ "pending" ] } ], [ "/attendances", { status: "all OR 1=1" } ],
      [ "/employees", { status: { bad: "active" } } ], [ "/pay_runs", { period: "2026-13" } ],
      [ "/", { period: [ "2026-11" ] } ], [ "/onboarding/cases", { status: "unknown" } ] ].each do |path, filters|
      get path, params: filters
      assert_response :not_found
    end
    leave(@employee)
    leave(@foreign)
    get "/leave_requests", params: { status: "pending", company_id: @other.id }
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "td", text: @foreign.full_name, count: 0
  end
  test "onboarding filtered pagination preserves status and exposes records beyond first page" do
    checklist = [ { "code" => "welcome", "title" => "Welcome", "done" => false, "required" => true } ]
    26.times do |n|
      OnboardingCase.create!(company: @admin.company, employee: @employee, start_date: Date.current + n, status: "in_progress", checklist: checklist)
    end
    login
    get "/"
    source = card_source("onboarding", 26)
    get source
    assert_response :success
    assert_select ".onboarding-card", count: 25
    first_ids = css_select(".onboarding-card").pluck("href")
    next_page = css_select(".pagination a").find { |node| node.text.include?("Trang tiếp") }["href"]
    assert_includes next_page, "status=in_progress"
    get next_page
    assert_response :success
    assert_select ".onboarding-card", count: 1
    assert_empty(first_ids & css_select(".onboarding-card").pluck("href"))
  end

  test "integration audit navigation requires both source and audit grants" do
    @admin.user_permissions.create!(permission: Permission.find_by!(key: "integration.read"), granted: false)
    login
    get "/"
    assert_response :success
    assert_select "a[href='/integration/audit']", count: 0
    assert_select "a[href='/integration']", count: 0
    get "/integration/audit"
    assert_response :forbidden
  end
  test "secondary metrics preserve scoped department recruitment and webhook sources" do
    [ @admin.company, @other ].each do |company|
      Candidate.create!(company: company, full_name: "Sample candidate", email: "candidate@example.test", position: "Engineer")
      connection = IntegrationConnection.create!(company: company, code: "SAMPLE", name: "Sample connection", public_id: SecureRandom.uuid, signing_secret: SecureRandom.hex(32))
      IntegrationWebhook.create!(company: company, integration_connection: connection, event_id: "sample.1", event_type: "sample.received", payload: "{}", body_digest: Digest::SHA256.hexdigest("{}"))
    end
    login
    get "/"
    sources = [ card_source("departments", 1), card_source("candidates", 1), card_source("webhooks", 1) ]
    assert_equal [ "/departments", "/candidates", "/integration" ], sources
    sources.each do |source|
      get source
      assert_response :success
    end
    login(@employee.user)
    get "/"
    assert_select ".metric-card[data-metric='candidates']", count: 0
    assert_select ".metric-card[data-metric='webhooks']", count: 0
  end
end
