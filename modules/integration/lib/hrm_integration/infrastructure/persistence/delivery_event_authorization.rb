module HrmIntegration
  module Infrastructure
    module Persistence
      class DeliveryEventAuthorization
        def self.allowed?(actor:, message:)
          type, id = message["type"] || message[:type], message["id"] || message[:id]
          return false unless id.is_a?(Integer) && id.positive?
          event = ::OutboxEvent.where(company_id: actor.company_id, id: id, event_type: type).first
          return false unless event && event.payload.is_a?(Hash)
          record_id = event.payload["record_id"]
          return false unless record_id.is_a?(Integer) && record_id.positive?
          scope = Pundit.policy_scope!(actor, ::IntegrationDelivery)
          case event.payload["record_type"]
          when "IntegrationDelivery"
            type.start_with?("integration_delivery.") && scope.exists?(record_id)
          when "IntegrationDeliveryAttempt"
            type.start_with?("integration_delivery_attempt.") && ::IntegrationDeliveryAttempt.exists?(company_id: actor.company_id, id: record_id, integration_delivery_id: scope.select(:id))
          else
            false
          end
        end
      end
    end
  end
end
