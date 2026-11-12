require "test_helper"
class ConcurrentOutboundTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  test "two MySQL workers perform one outbound send and append one attempt" do
    company = Company.create!(code: "HUBRACE#{SecureRandom.hex(4).upcase}", name: "Webhook race test")
    admin = make_user(:admin, company: company)
    result = HrmIntegration::Application::Commands::CreateConnection.new.call(actor: admin, attributes: { code: "RACE", name: "Race" })
    connection = HrmIntegration::Application::Commands::ToggleConnection.new.call(actor: admin, id: result[:record].id, active: true, lock_version: 0)
    previous_targets = ENV["INTEGRATION_TARGETS_JSON"]
    ENV["INTEGRATION_TARGETS_JSON"] = { partner: { url: "https://partner.example.test/hook", company_ids: [ company.id ] } }.to_json
    input = { actor: admin, connection_id: connection.id, target_key: "partner", body: { event_type: "external.notification", payload: { reference: 1 } }.to_json, idempotency_key: "one-send" }
    record = HrmIntegration::Application::Commands::QueueDelivery.new.call(**input)
    network_calls = Queue.new
    transport = ->(**) { network_calls << true; { code: 200, outcome: "delivered" } }
    gate, outcomes = Queue.new, Queue.new
    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
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
    end
    2.times { gate << true }
    threads.each { |thread| assert thread.join(20), "Webhook lock timed out" }
    responses = Array.new(2) { outcomes.pop }
    responses.each { |response| raise response if response.is_a?(Exception) }
    assert_equal 1, network_calls.size
    assert_equal "delivered", record.reload.status
    assert_equal 1, record.attempt_count
    assert_equal 1, IntegrationDeliveryAttempt.where(company_id: company.id).count
    assert_equal 1, OutboxEvent.where(company_id: company.id, event_type: "integration_delivery_attempt.created").count
  ensure
    ENV["INTEGRATION_TARGETS_JSON"] = previous_targets
    Array(threads).each { |thread| thread.kill if thread.alive? }
    if company&.persisted?
      [ IntegrationDeliveryAttempt, IntegrationDelivery, IntegrationConnection, AuditLog, OutboxEvent ].each { |model| model.where(company_id: company.id).delete_all }
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
