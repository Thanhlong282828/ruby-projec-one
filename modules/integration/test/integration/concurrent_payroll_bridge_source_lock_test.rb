require "test_helper"
class ConcurrentPayrollBridgeSourceLockTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  test "source grant revoked while waiting for artifact lock blocks payroll network" do
    company = Company.create!(code: "HUBRACE#{SecureRandom.hex(4).upcase}", name: "Webhook race test")
    admin = make_user(:admin, company: company)
    result = HrmIntegration::Application::Commands::CreateConnection.new.call(actor: admin, attributes: { code: "RACE", name: "Race" })
    connection = HrmIntegration::Application::Commands::ToggleConnection.new.call(actor: admin, id: result[:record].id, active: true, lock_version: 0)
    previous_targets = ENV["INTEGRATION_TARGETS_JSON"]
    ENV["INTEGRATION_TARGETS_JSON"] = { partner: { url: "https://partner.example.test/hook", company_ids: [ company.id ] } }.to_json
    make_employee(admin)
    run = Payroll::BuildRun.call(period: Date.current, actor: admin)
    Payroll::FinalizeRun.call(run: run, actor: admin)
    source = HrmPayroll::Application::Commands::CreateExport.new.call(actor: admin, pay_run_id: run.id)
    record = HrmIntegration::Application::Commands::QueuePayrollNotification.new.call(actor: admin,
      export_id: source.id, connection_id: connection.id, target_key: "partner")
    network_calls = Queue.new
    transport = ->(**) { network_calls << true; { code: 200, outcome: "delivered" } }
    ready, outcomes = Queue.new, Queue.new
    worker = nil
    observer = Object.new
    observer.define_singleton_method(:start) do |_name, _id, payload|
      if Thread.current == worker && payload[:sql].include?("payroll_exports") && payload[:sql].include?("FOR UPDATE")
        ready << true
      end
    end
    observer.define_singleton_method(:finish) { |*| nil }
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record", observer)
    source.with_lock do
      worker = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          begin
            HrmIntegration::Infrastructure::Persistence::ActiveRecordDeliveryRepository.new(transport: transport).deliver!(id: record.id)
            outcomes << :ok
          rescue StandardError => error
            outcomes << error
          ensure
            Current.reset
          end
        end
      end
      Timeout.timeout(10) { ready.pop }
      admin.user_permissions.create!(permission: Permission.find_by!(key: "payroll.exports.notify"), granted: false)
    end
    assert worker.join(20), "Connection lock timed out"
    response = outcomes.pop
    raise response if response.is_a?(Exception)
    assert_equal 0, network_calls.size
    assert_equal "blocked", record.reload.status
    assert_equal 0, record.attempt_count
    assert_equal 0, IntegrationDeliveryAttempt.where(company_id: company.id).count
  ensure
    ENV["INTEGRATION_TARGETS_JSON"] = previous_targets
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    worker.kill if worker&.alive?
    if company&.persisted?
      [ IntegrationDeliveryAttempt, IntegrationDelivery, IntegrationConnection, PayrollExportAccess, PayrollExport, Payslip, PayRun, Employee, Department, AuditLog, OutboxEvent ].each { |model| model.where(company_id: company.id).delete_all }
      ids = User.where(company_id: company.id).pluck(:id)
      UserPermission.where(user_id: ids).delete_all
      ApiToken.where(user_id: ids).delete_all
      LoginSession.where(user_id: ids).delete_all
      User.where(company_id: company.id).delete_all
      RolePermission.where(company_role_id: CompanyRole.where(company_id: company.id).select(:id)).delete_all
      CompanyRole.where(company_id: company.id).delete_all
      company.reload.destroy!
    end
  end
end
