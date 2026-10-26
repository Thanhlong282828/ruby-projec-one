require "test_helper"
class LayeredFormsTest < ActionDispatch::IntegrationTest
  test "invalid employee form still renders prepared department and user options" do
    admin = make_user(:admin)
    make_employee
    post "/session", params: { email: admin.email, password: "StrongPassword123!" }
    post "/employees", params: { employee: { full_name: "Incomplete" } }
    assert_response :unprocessable_entity
    assert_select "select[name='employee[department_id]'] option"
    assert_select "select[name='employee[user_id]'] option"
  end
  test "staff payroll show renders prepared payslip data" do
    admin = make_user(:admin)
    employee = make_employee
    run = HrmPayroll::Application::Commands::BuildPayRun.new.call(period: Date.current, actor: admin)
    post "/session", params: { email: admin.email, password: "StrongPassword123!" }
    get "/pay_runs/#{run.id}"
    assert_response :success
    assert_includes response.body, employee.full_name
  end
end
