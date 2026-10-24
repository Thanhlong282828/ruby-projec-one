require "test_helper"
class PayrollDomainTest < ActiveSupport::TestCase
  test "payroll snapshot is stable and finalize is one way" do
    employee = make_employee
    admin = make_user(:admin)
    run = Payroll::BuildRun.call(period: Date.new(2026, 10, 20), actor: admin)
    assert_equal Date.new(2026, 10, 1), run.period
    employee.update!(salary_cents: 30000000)
    assert_equal 20000000, run.payslips.find_by!(employee: employee).net_cents
    Payroll::FinalizeRun.call(run: run, actor: admin)
    assert run.reload.finalized?
    assert_raises(TimeOff::Review::InvalidTransition) { Payroll::FinalizeRun.call(run: run, actor: admin) }
  end
  test "employee cannot build payroll" do
    assert_raises(Pundit::NotAuthorizedError) { Payroll::BuildRun.call(period: Date.current, actor: make_user) }
  end
end
