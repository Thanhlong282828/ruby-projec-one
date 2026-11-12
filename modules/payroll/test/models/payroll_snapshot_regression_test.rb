require "test_helper"
require "minitest/mock"

class PayrollSnapshotRegressionTest < ActiveSupport::TestCase
  test "employee identity in payroll export remains the identity captured by the run" do
    admin = make_user(:admin)
    employee = make_employee(employee_code: "ORIGINAL", full_name: "Original employee")
    run = Payroll::BuildRun.call(period: Date.current, actor: admin)
    employee.update!(employee_code: "CHANGED", full_name: "Changed employee", salary_cents: 30_000_000)
    Payroll::FinalizeRun.call(run: run, actor: admin)
    export = HrmPayroll::Application::Commands::CreateExport.new.call(actor: admin, pay_run_id: run.id)
    assert_includes export.artifact, "ORIGINAL"
    assert_not_includes export.artifact, "CHANGED"
    assert_equal "Original employee", run.payslips.first.employee_name_snapshot
  end

  test "payslip financial snapshot cannot be changed through normal model writes" do
    admin = make_user(:admin)
    make_employee
    run = Payroll::BuildRun.call(period: Date.current, actor: admin)
    Payroll::FinalizeRun.call(run: run, actor: admin)
    slip = run.payslips.first
    assert_raises(ActiveRecord::ReadOnlyRecord) { slip.update!(gross_cents: 1, net_cents: 1) }
    assert_equal 20_000_000, slip.reload.net_cents
  end

  test "persisted company scope is checked rather than trusting the caller run object" do
    admin = make_user(:admin)
    other = make_user(:admin, company: Company.create!(code: "PAY#{SecureRandom.hex(3).upcase}", name: "Other company"))
    make_employee(other)
    run = Payroll::BuildRun.call(period: Date.current, actor: other)
    run.company_id = admin.company_id
    assert_raises(ActiveRecord::RecordNotFound) do
      HrmPayroll::Application::Queries::ListPayslips.new.call(actor: admin, run: run)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      HrmPayroll::Application::Queries::ReconcilePayRun.new.call(actor: admin, run: run)
    end
  end
  class FailingOutbox < HrmPlatform::Domain::Repositories::OutboxRepositoryInterface
    def append!(**) = raise(IOError, "outbox unavailable")
  end

  test "closing audit outbox and reconciliation roll back together" do
    admin = make_user(:admin)
    make_employee
    run = Payroll::BuildRun.call(period: Date.current, actor: admin)
    counts = [ AuditLog.count, OutboxEvent.count ]
    original = Hrm::Container.method(:resolve)
    resolver = lambda do |contract|
      contract.to_s == "HrmPlatform::Domain::Repositories::OutboxRepositoryInterface" ? FailingOutbox.new : original.call(contract)
    end
    Hrm::Container.stub(:resolve, resolver) do
      assert_raises(IOError) { Payroll::FinalizeRun.call(run: run, actor: admin) }
    end
    assert run.reload.draft?
    assert_nil run.finalized_at
    assert_nil run.reconciliation_snapshot
    assert_equal counts, [ AuditLog.count, OutboxEvent.count ]
  end

  class FailingAudit < HrmAudit::Domain::Repositories::WriteRepositoryInterface
    def append!(**) = raise(IOError, "audit unavailable")
  end

  test "audit failure rolls back closing status snapshot and outbox" do
    admin = make_user(:admin)
    make_employee
    run = Payroll::BuildRun.call(period: Date.current, actor: admin)
    counts = [ AuditLog.count, OutboxEvent.count ]
    original = Hrm::Container.method(:resolve)
    resolver = lambda do |contract|
      contract == HrmAudit::Domain::Repositories::WriteRepositoryInterface ? FailingAudit.new : original.call(contract)
    end
    Hrm::Container.stub(:resolve, resolver) do
      assert_raises(IOError) { Payroll::FinalizeRun.call(run: run, actor: admin) }
    end
    assert run.reload.draft?
    assert_nil run.finalized_at
    assert_nil run.reconciliation_snapshot
    assert_equal counts, [ AuditLog.count, OutboxEvent.count ]
  end

  test "strict read contract preserves nil pagination and reconciliation projections" do
    admin = make_user(:admin)
    make_employee
    run = Payroll::BuildRun.call(period: Date.current, actor: admin)
    repository = Hrm::Container.resolve(HrmPayroll::Domain::Repositories::ReadRepositoryInterface)
    assert_equal [ run.id ], repository.list(actor: admin, page: nil).map(&:id)
    draft = repository.reconciliation(actor: admin, run: run)
    assert_nil draft[:captured]
    assert_equal 1, draft[:current].fetch("payslip_count")
    Payroll::FinalizeRun.call(run: run, actor: admin)
    closed = repository.reconciliation(actor: admin, run: run)
    assert_nil closed[:current]
    assert_equal 20_000_000, closed[:captured].fetch("net_total")
    admin.user_permissions.create!(permission: Permission.find_by!(key: "leave.read_all"), granted: false)
    restricted = repository.reconciliation(actor: admin, run: run)
    assert_not restricted[:source_visible]
    assert_nil restricted[:captured]
    assert_nil restricted[:current]
  end

  test "strict use cases still reject missing actors through authorization" do
    admin = make_user(:admin)
    make_employee
    run = Payroll::BuildRun.call(period: Date.current, actor: admin)
    assert_raises(Pundit::NotAuthorizedError) { HrmPayroll::Application::Commands::FinalizePayRun.new.call(run: run, actor: nil) }
    assert_raises(Pundit::NotAuthorizedError) { HrmPayroll::Application::Queries::ListPayslips.new.call(run: run, actor: nil) }
    assert_raises(Pundit::NotAuthorizedError) { HrmPayroll::Application::Queries::ReconcilePayRun.new.call(run: run, actor: nil) }
    assert run.reload.draft?
  end

  test "source warnings are captured without introducing an automatic closing policy or deductions" do
    admin = make_user(:admin)
    employee = make_employee
    HrmAttendance::Application::Commands::CheckIn.new.call(actor: employee.user, at: Time.current)
    employee.leave_requests.create!(starts_on: Date.current, ends_on: Date.current, reason: "Pending sample")
    run = Payroll::BuildRun.call(period: Date.current, actor: admin)
    Payroll::FinalizeRun.call(run: run, actor: admin)
    captured = run.reload.reconciliation_snapshot
    assert_equal 1, captured.fetch("open_attendance_count")
    assert_equal 1, captured.fetch("pending_leave_count")
    assert_equal 20_000_000, captured.fetch("net_total")
    assert_raises(ActiveRecord::ReadOnlyRecord) { run.update!(reconciliation_snapshot: {}) }
  end
end
