require "test_helper"
class HrmTest < ActiveSupport::TestCase
  test "employee validates uniqueness and nonnegative salary" do
    employee = make_employee
    duplicate = Employee.new(employee.attributes.except("id", "created_at", "updated_at"))
    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :employee_code
    employee.salary_cents = -1
    assert_not employee.valid?
  end
  test "sensitive fields are encrypted at rest" do
    employee = make_employee(bank_account: "1234567890", national_id: "SECRET-ID")
    raw = Employee.connection.select_one("SELECT bank_account, national_id FROM employees WHERE id = #{employee.id}")
    assert_not_equal "1234567890", raw["bank_account"]
    assert_not_equal "SECRET-ID", raw["national_id"]
    assert_equal "1234567890", employee.reload.bank_account
  end
  test "audit and outbox roll back with employee transaction" do
    before_counts = [Employee.count, AuditLog.count, OutboxEvent.count]
    Employee.transaction do
      make_employee
      raise ActiveRecord::Rollback
    end
    assert_equal before_counts, [Employee.count, AuditLog.count, OutboxEvent.count]
  end
  test "observer attributes changes without storing sensitive values" do
    actor = make_user(:admin)
    Current.user = actor
    employee = make_employee(bank_account: "secret-value")
    log = AuditLog.find_by!(record_type: "Employee", record_id: employee.id)
    assert_equal actor.id, log.actor_id
    assert_not_includes log.metadata.to_json, "secret-value"
    assert_not_includes log.metadata["changed_fields"], "bank_account"
  end
  test "leave rejects reversed dates and overlapping intervals" do
    employee = make_employee
    TimeOff::Submit.call(employee: employee, attributes: { starts_on: Date.new(2026, 11, 1), ends_on: Date.new(2026, 11, 3), reason: "Holiday" })
    overlap = employee.leave_requests.new(starts_on: Date.new(2026, 11, 3), ends_on: Date.new(2026, 11, 5), reason: "Holiday")
    assert_not overlap.valid?
    invalid = employee.leave_requests.new(starts_on: Date.new(2026, 11, 8), ends_on: Date.new(2026, 11, 5), reason: "Holiday")
    assert_not invalid.valid?
  end
  test "leave review prevents self approval and repeated transition" do
    employee = make_employee(make_user(:hr))
    request = employee.leave_requests.create!(starts_on: Date.new(2026, 11, 1), ends_on: Date.new(2026, 11, 2), reason: "Family")
    assert_raises(Pundit::NotAuthorizedError) { TimeOff::Review.call(request: request, reviewer: employee.user, decision: "approved") }
    reviewer = make_user(:hr)
    TimeOff::Review.call(request: request, reviewer: reviewer, decision: "approved")
    assert request.reload.approved?
    assert_equal reviewer.id, request.reviewer_id
    assert_raises(TimeOff::Review::InvalidTransition) { TimeOff::Review.call(request: request, reviewer: reviewer, decision: "rejected") }
  end
  test "leave review enforces yearly balance" do
    employee = make_employee(annual_leave_days: 1)
    request = employee.leave_requests.create!(starts_on: Date.new(2026, 11, 1), ends_on: Date.new(2026, 11, 2), reason: "Family")
    assert_raises(TimeOff::Review::InvalidTransition) { TimeOff::Review.call(request: request, reviewer: make_user(:hr), decision: "approved") }
    assert request.reload.pending?
  end
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
  test "attendance is unique per employee per day" do
    employee = make_employee
    employee.attendances.create!(work_date: Date.current, checked_in_at: Time.current)
    assert_not employee.attendances.new(work_date: Date.current, checked_in_at: Time.current).valid?
  end
  test "department with employees cannot be removed" do
    employee = make_employee
    assert_not employee.department.destroy
  end
  test "expired token is excluded and raw token never persisted" do
    user = make_user
    raw = ApiToken.issue!(user)
    assert_nil ApiToken.find_by(digest: raw)
    token = user.api_tokens.last
    token.update!(expires_at: 1.minute.ago)
    assert_not ApiToken.valid_now.exists?(token.id)
  end
end
