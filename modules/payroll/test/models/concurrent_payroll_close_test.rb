require "test_helper"
require "timeout"

class ConcurrentPayrollCloseTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  def setup
    super
    @company = Company.create!(code: "CLOSERACE#{SecureRandom.hex(3).upcase}", name: "Closing race")
    @admin = make_user(:admin, company: @company)
    @employee = make_employee(make_user(:employee, company: @company))
    @run = Payroll::BuildRun.call(period: Date.new(2026, 11, 1), actor: @admin)
    @threads = []
  end

  def teardown
    @threads.each { |thread| thread.kill if thread.alive? }
    ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber
    [ PayrollExportAccess, PayrollExport, Payslip, PayRun, Attendance, LeaveRequest, Employee, Department, AuditLog, OutboxEvent ].each { |model| model.where(company_id: @company.id).delete_all }
    ids = User.where(company_id: @company.id).pluck(:id)
    [ UserPermission, ApiToken, LoginSession ].each { |model| model.where(user_id: ids).delete_all }
    User.where(id: ids).delete_all
    RolePermission.where(company_role_id: CompanyRole.where(company_id: @company.id).select(:id)).delete_all
    CompanyRole.where(company_id: @company.id).delete_all
    @company.reload.destroy!
    super
  end

  test "two closing requests commit one reconciliation and one closing audit" do
    gate, results = Queue.new, Queue.new
    @threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          begin
            Payroll::FinalizeRun.call(run: @run, actor: @admin)
            results << :closed
          rescue StandardError => error
            results << error
          ensure
            Current.reset
          end
        end
      end
    end
    2.times { gate << true }
    @threads.each { |thread| assert thread.join(20), "Payroll closing lock timed out" }
    outcomes = Array.new(2) { results.pop }
    assert_equal 1, outcomes.count(:closed)
    assert_equal(1, outcomes.count { |value| value.is_a?(TimeOff::Review::InvalidTransition) })
    assert @run.reload.finalized?
    assert_equal 20_000_000, @run.reconciliation_snapshot.fetch("net_total")
    audit = AuditLog.where(company_id: @company.id, record_type: "PayRun", record_id: @run.id, action: "updated")
    assert_equal 1, audit.count
    assert_equal @admin.id, audit.first.actor_id
  end

  test "revoked finalize grant is rechecked after waiting for the payroll lock" do
    ready, result = Queue.new, Queue.new
    observer = Object.new
    owner = self
    observer.define_singleton_method(:start) do |_, _, payload|
      ready << true if Thread.current == owner.instance_variable_get(:@worker) && payload[:sql].include?("FOR UPDATE") && payload[:sql].include?("pay_runs")
    end
    observer.define_singleton_method(:finish) { |*| nil }
    @subscriber = ActiveSupport::Notifications.subscribe("sql.active_record", observer)
    @run.with_lock do
      @worker = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          begin
            ActiveRecord::Base.cache { Payroll::FinalizeRun.call(run: @run, actor: @admin) }
            result << :closed
          rescue StandardError => error
            result << error
          ensure
            Current.reset
          end
        end
      end
      @threads << @worker
      Timeout.timeout(10) { ready.pop }
      @admin.user_permissions.create!(permission: Permission.find_by!(key: "payroll.finalize"), granted: false)
    end
    assert @worker.join(20), "Permission recheck lock timed out"
    assert_kind_of Pundit::NotAuthorizedError, result.pop
    assert @run.reload.draft?
    assert_nil @run.reconciliation_snapshot
  end
  test "revoked CSV download grant is rechecked after waiting for artifact lock with query cache" do
    Payroll::FinalizeRun.call(run: @run, actor: @admin)
    export = HrmPayroll::Application::Commands::CreateExport.new.call(actor: @admin, pay_run_id: @run.id)
    ready, result = Queue.new, Queue.new
    observer = Object.new
    owner = self
    observer.define_singleton_method(:start) do |_, _, payload|
      ready << true if Thread.current == owner.instance_variable_get(:@worker) && payload[:sql].include?("FOR UPDATE") && payload[:sql].include?("payroll_exports")
    end
    observer.define_singleton_method(:finish) { |*| nil }
    @subscriber = ActiveSupport::Notifications.subscribe("sql.active_record", observer)
    export.with_lock do
      @worker = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          begin
            value = ActiveRecord::Base.cache { HrmPayroll::Application::Commands::DownloadExport.new.call(actor: @admin, id: export.id) }
            result << value
          rescue StandardError => error
            result << error
          ensure
            Current.reset
          end
        end
      end
      @threads << @worker
      Timeout.timeout(10) { ready.pop }
      @admin.user_permissions.create!(permission: Permission.find_by!(key: "payroll.exports.download"), granted: false)
    end
    assert @worker.join(20), "Download authorization lock timed out"
    assert_kind_of Pundit::NotAuthorizedError, result.pop
    assert_equal 0, export.payroll_export_accesses.count
  end

  test "reconciliation does not retain revoked source grants in an outer query cache" do
    query = HrmPayroll::Application::Queries::ReconcilePayRun.new
    ActiveRecord::Base.cache do
      assert query.call(actor: @admin, run: @run).fetch(:source_visible)
      worker = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          @admin.user_permissions.create!(permission: Permission.find_by!(key: "leave.read_all"), granted: false)
        end
      end
      @threads << worker
      assert worker.join(10)
      result = query.call(actor: @admin, run: @run)
      assert_not result.fetch(:source_visible)
      assert_nil result[:current]
      assert_nil result[:captured]
    end
  end
end
