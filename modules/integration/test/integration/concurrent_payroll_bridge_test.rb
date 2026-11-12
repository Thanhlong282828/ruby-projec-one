require "test_helper"
class ConcurrentPayrollBridgeTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  test "two MySQL connections queue one source-bound payroll notification" do
    company = Company.create!(code: "EXPRACE#{SecureRandom.hex(4).upcase}", name: "Export race test")
    admin = make_user(:admin, company: company)
    make_employee(admin)
    run = Payroll::BuildRun.call(period: Date.current, actor: admin)
    Payroll::FinalizeRun.call(run: run, actor: admin)
    source = HrmPayroll::Application::Commands::CreateExport.new.call(actor: admin, pay_run_id: run.id)
    connection = HrmIntegration::Application::Commands::CreateConnection.new.call(actor: admin, attributes: { code: "PAYROLL", name: "Partner" })[:record]
    HrmIntegration::Application::Commands::ToggleConnection.new.call(actor: admin, id: connection.id, active: true, lock_version: 0)
    previous_targets = ENV["INTEGRATION_TARGETS_JSON"]
    ENV["INTEGRATION_TARGETS_JSON"] = { partner: { url: "https://partner.example.test/hook", company_ids: [ company.id ] } }.to_json
    gate, results = Queue.new, Queue.new
    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          begin
            results << HrmIntegration::Application::Commands::QueuePayrollNotification.new.call(actor: admin, export_id: source.id, connection_id: connection.id, target_key: "partner").id
          rescue StandardError => error
            results << error
          ensure
    ENV["INTEGRATION_TARGETS_JSON"] = previous_targets
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
    assert_equal 1, IntegrationDelivery.where(company_id: company.id, payroll_export_id: source.id).count
    assert_equal 1, OutboxEvent.where(company_id: company.id, event_type: "integration_delivery.created").count
  ensure
    ENV["INTEGRATION_TARGETS_JSON"] = previous_targets
    Array(threads).each { |thread| thread.kill if thread.alive? }
    if company&.persisted?
      [ IntegrationDeliveryAttempt, IntegrationDelivery, IntegrationConnection, PayrollExportAccess, PayrollExport, Payslip, PayRun, Employee, Department, AuditLog, OutboxEvent ].each { |model| model.where(company_id: company.id).delete_all }
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
