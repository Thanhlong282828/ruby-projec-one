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
end
