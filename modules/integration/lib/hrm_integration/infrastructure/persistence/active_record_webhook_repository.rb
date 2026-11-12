module HrmIntegration
  module Infrastructure
    module Persistence
      class ActiveRecordWebhookRepository < Domain::Repositories::WebhookRepositoryInterface
        def receive!(public_id:, timestamp:, event_id:, signature:, body:)
          verifier = Domain::Services::WebhookSignature
          raise verifier::Unauthorized unless public_id.is_a?(String) && /\A[0-9a-f-]{36}\z/.match?(public_id)
          connection = ::IntegrationConnection.find_by(public_id: public_id)
          raise verifier::Unauthorized unless connection
          connection.with_lock do
            raise verifier::Unauthorized unless connection.active? && ::Company.exists?(id: connection.company_id, active: true)
            verifier.verify!(secret: connection.signing_secret, timestamp: timestamp, event_id: event_id, signature: signature, body: body)
            data = verifier.parse!(body)
            digest = Digest::SHA256.hexdigest(body)
            existing = connection.integration_webhooks.find_by(event_id: event_id)
            if existing
              raise verifier::Conflict unless ActiveSupport::SecurityUtils.secure_compare(existing.body_digest, digest)
              return { id: existing.id, duplicate: true }
            end
            record = nil
            Current.set(user: nil) do
              record = connection.integration_webhooks.create!(company_id: connection.company_id,
                event_id: event_id, event_type: data.fetch("event_type"), body_digest: digest,
                payload: body.dup.force_encoding(Encoding::UTF_8), status: "received")
            end
            { id: record.id, duplicate: false }
          end
        end
      end
    end
  end
end
