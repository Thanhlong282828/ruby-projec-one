require "test_helper"
class ConcurrentWebhooksTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  test "two MySQL connections accept one receipt for a repeated event" do
    company = Company.create!(code: "HUBRACE#{SecureRandom.hex(4).upcase}", name: "Webhook race test")
    admin = make_user(:admin, company: company)
    result = HrmIntegration::Application::Commands::CreateConnection.new.call(actor: admin, attributes: { code: "RACE", name: "Race" })
    connection = HrmIntegration::Application::Commands::ToggleConnection.new.call(actor: admin, id: result[:record].id, active: true, lock_version: 0)
    body = { event_type: "external.notification", payload: { reference: 1 } }.to_json
    timestamp = Time.current.to_i.to_s
    input = { public_id: connection.public_id, timestamp: timestamp, event_id: "same-event", body: body,
      signature: OpenSSL::HMAC.hexdigest("SHA256", result[:secret], "#{timestamp}.same-event.#{body}") }
    gate, outcomes = Queue.new, Queue.new
    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          begin
            outcomes << HrmIntegration::Application::Commands::ReceiveWebhook.new.call(**input)
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
    assert_equal [ false, true ], responses.pluck(:duplicate).sort_by(&:to_s)
    assert_equal 1, responses.pluck(:id).uniq.size
    assert_equal 1, IntegrationWebhook.where(company_id: company.id).count
    assert_equal 1, OutboxEvent.where(company_id: company.id, event_type: "integration_webhook.created").count
  ensure
    Array(threads).each { |thread| thread.kill if thread.alive? }
    if company&.persisted?
      [ IntegrationWebhook, IntegrationConnection, AuditLog, OutboxEvent ].each { |model| model.where(company_id: company.id).delete_all }
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
