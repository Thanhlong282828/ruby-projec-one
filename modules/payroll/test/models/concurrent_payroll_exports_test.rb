require "test_helper"
class ConcurrentPayrollExportsTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  test "two MySQL connections create one immutable payroll snapshot" do
    company = Company.create!(code: "EXPRACE#{SecureRandom.hex(4).upcase}", name: "Export race test")
    admin = make_user(:admin, company: company)
    make_employee(admin)
    run = Payroll::BuildRun.call(period: Date.current, actor: admin)
    Payroll::FinalizeRun.call(run: run, actor: admin)
    gate, results = Queue.new, Queue.new
    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          begin
            results << HrmPayroll::Application::Commands::CreateExport.new.call(actor: admin, pay_run_id: run.id).id
          rescue StandardError => error
            results << error
          ensure
            Current.reset
          end
        end
      end
    end
    2.times { gate << true }
    threads.each { |thread| assert thread.join(20), "Export lock timed out" }
    ids = Array.new(2) { results.pop }
    ids.each { |value| raise value if value.is_a?(Exception) }
    assert_equal 1, ids.uniq.size
    assert_equal 1, PayrollExport.where(company_id: company.id).count
    assert_equal 1, OutboxEvent.where(company_id: company.id, event_type: "payroll_export.created").count
  ensure
    Array(threads).each { |thread| thread.kill if thread.alive? }
    if company&.persisted?
      [ PayrollExportAccess, PayrollExport, Payslip, PayRun, Employee, Department, AuditLog, OutboxEvent ].each { |model| model.where(company_id: company.id).delete_all }
      users = User.where(company_id: company.id).pluck(:id)
      UserPermission.where(user_id: users).delete_all
      ApiToken.where(user_id: users).delete_all
      LoginSession.where(user_id: users).delete_all
      User.where(company_id: company.id).delete_all
      RolePermission.where(company_role_id: CompanyRole.where(company_id: company.id).select(:id)).delete_all
      CompanyRole.where(company_id: company.id).delete_all
      company.reload.destroy!
    end
  end
end
