require "test_helper"
class WebTest < ActionDispatch::IntegrationTest
  test "browser login renders all admin screens and forms" do
    user = make_user(:admin)
    employee = make_employee
    get "/"
    assert_redirected_to new_session_path
    post "/session", params: { email: user.email, password: "StrongPassword123!" }
    assert_redirected_to root_path
    ["/", "/employees", "/employees/new", "/employees/#{employee.id}", "/employees/#{employee.id}/edit", "/departments", "/departments/new", "/leave_requests", "/leave_requests/new", "/attendances", "/pay_runs", "/pay_runs/new", "/candidates", "/candidates/new", "/audit_logs"].each do |path|
      get path
      assert_response :success, path
    end
    delete "/session"
    get "/employees"
    assert_redirected_to new_session_path
  end
  test "ordinary employees cannot access admin screens" do
    employee = make_employee
    post "/session", params: { email: employee.user.email, password: "StrongPassword123!" }
    ["/departments", "/pay_runs", "/candidates", "/audit_logs", "/employees/new"].each do |path|
      get path
      assert_response :forbidden, path
    end
  end
  test "employee submits leave and clocks in and out" do
    employee = make_employee
    post "/session", params: { email: employee.user.email, password: "StrongPassword123!" }
    post "/leave_requests", params: { leave_request: { employee_id: employee.id, starts_on: "2026-11-01", ends_on: "2026-11-02", reason: "Family" } }
    assert_redirected_to leave_requests_path
    assert_equal 1, employee.leave_requests.count
    post "/attendances"
    assert_redirected_to attendances_path
    attendance = employee.attendances.last
    patch "/attendances/#{attendance.id}/checkout"
    assert_not_nil attendance.reload.checked_out_at
  end
end
