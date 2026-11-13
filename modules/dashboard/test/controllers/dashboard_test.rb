require "test_helper"
class DashboardModuleTest < ActionDispatch::IntegrationTest
  test "employee dashboard omits organization-wide payroll and recruitment controls" do
    employee = make_employee
    post "/session", params: { email: employee.user.email, password: "StrongPassword123!" }
    get "/"
    assert_response :success
    assert_select "a[href='/pay_runs']", count: 0
    assert_select "a[href='/candidates']", count: 0
  end
  test "dashboard metrics link to tenant-scoped source lists and board groups" do
    admin = make_user(:admin)
    make_employee(admin)
    post "/session", params: { email: admin.email, password: "StrongPassword123!" }
    get "/"
    assert_response :success
    assert_select ".metric-card[data-metric='employees'] strong", text: "1"
    assert_select ".metric-card[data-metric='pending']"
    assert_select ".workspace-board .module-widget", count: 9
    assert_select "nav details summary", text: "Chấm công"
    source = css_select(".metric-card[data-metric='employees']").first["href"]
    get source
    assert_response :success
    assert_select "td", text: /#{Regexp.escape(admin.employee.full_name)}/
  end

  test "metric counts exclude another company and disappear after permission revocation" do
    employee = make_employee
    other_company = Company.create!(code: "ERP#{SecureRandom.hex(4).upcase}", name: "Other")
    make_employee(make_user(company: other_company))
    post "/session", params: { email: employee.user.email, password: "StrongPassword123!" }
    get "/"
    assert_select ".metric-card[data-metric='employees'] strong", text: "1"
    employee.user.user_permissions.create!(permission: Permission.find_by!(key: "employees.read"), granted: false)
    get "/"
    assert_response :success
    assert_select "a[href='/employees']", count: 0
  end
  test "every visible ERP menu entry resolves to an authorized working page" do
    admin = make_user(:admin)
    post "/session", params: { email: admin.email, password: "StrongPassword123!" }
    get "/"
    paths = css_select("nav a").pluck("href").uniq
    assert_includes paths, "/onboarding/cases"
    paths.each do |path|
      get path
      assert_response :success, "ERP menu points to an unavailable page: #{path}"
    end
  end

  test "dashboard remains accessible when leave read permission is revoked" do
    employee = make_employee
    employee.user.user_permissions.create!(permission: Permission.find_by!(key: "leave.read"), granted: false)
    post "/session", params: { email: employee.user.email, password: "StrongPassword123!" }
    get "/"
    assert_response :success
    assert_select "a[href='/leave_requests']", count: 0
    assert_select ".metric-card[data-metric='employees']"
  end
end
