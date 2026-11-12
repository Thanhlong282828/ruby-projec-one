module HrmIntegration
  module Infrastructure
    module Persistence
      class ActiveRecordOutboundWriteRepository < Domain::Repositories::OutboundWriteRepositoryInterface
        def enqueue!(actor:, connection_id:, target_key:, body:, idempotency_key:)
          Pundit.authorize(actor, ::IntegrationDelivery, :create?)
          invalid! unless target_key.is_a?(String) && Http::OutboundTransport.targets(company_id: actor.company_id).key?(target_key)
          invalid! unless idempotency_key.is_a?(String) && /\A[A-Za-z0-9][A-Za-z0-9_.:-]{0,99}\z/.match?(idempotency_key)
          invalid! if idempotency_key.start_with?("payroll-v1:")
          invalid! unless body.is_a?(String) && body.bytesize.between?(1, Domain::Services::WebhookSignature::MAX_BYTES)
          body = Domain::Services::OutboundEnvelope.verify!(body: body)
          connection = Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface).connection!(actor: actor, id: connection_id)
          connection.with_lock do
            ActiveRecord::Base.uncached { Pundit.authorize(actor, ::IntegrationDelivery, :create?) }
            existing = ::IntegrationDelivery.find_by(company_id: actor.company_id, idempotency_key: idempotency_key)
            if existing
              same = existing.integration_connection_id == connection.id && existing.target_key == target_key && ActiveSupport::SecurityUtils.secure_compare(existing.body_digest, Digest::SHA256.hexdigest(body))
              raise Domain::Services::WebhookSignature::Conflict unless same
              return existing
            end
            invalid! unless connection.active?
            Current.set(user: actor) do
              ::IntegrationDelivery.create!(company_id: actor.company_id, integration_connection: connection, requested_by: actor,
                target_key: target_key, payload: body, body_digest: Digest::SHA256.hexdigest(body), event_id: SecureRandom.uuid,
                idempotency_key: idempotency_key, status: "queued", available_at: Time.current)
            end
          end
        rescue ActiveRecord::RecordNotUnique
          # A different connection may race on the same company idempotency key. Never silently accept it.
          raise Domain::Services::WebhookSignature::Conflict
        end
        def retry!(actor:, id:, lock_version:)
          data = Hrm::Container.resolve(Domain::Repositories::OutboundReadRepositoryInterface).find!(actor: actor, id: id)
          record = data[:record]
          record.with_lock do
            Hrm::Container.resolve(HrmPayroll::Domain::Repositories::ExportSourceRepositoryInterface).lock_for_delivery!(company_id: record.company_id, id: record.payroll_export_id) if record.payroll_export_id
            ActiveRecord::Base.uncached { Pundit.authorize(actor, record, :retry?) }
            valid = (lock_version.is_a?(Integer) && lock_version >= 0) || (lock_version.is_a?(String) && /\A[0-9]{1,10}\z/.match?(lock_version))
            raise ActiveRecord::StaleObjectError.new(record, "update") unless valid && record.lock_version == lock_version.to_i
            invalid! unless %w[retry_wait dead_letter blocked].include?(record.status) && record.replay_count < 10
            verified_body!(actor, record)
            # Preserve attempt sequence/history; each replay allows a new bounded five-attempt cycle.
            Current.set(user: actor) { record.update!(status: "queued", cycle_attempt_count: 0, replay_count: record.replay_count + 1, available_at: Time.current) }
            record
          end
        end
        private
        def verified_body!(actor, record)
          Domain::Services::PayrollNotification.verify!(actor: actor, record: record, source_repository: Hrm::Container.resolve(HrmPayroll::Domain::Repositories::ExportSourceRepositoryInterface))
        rescue ActiveRecord::Encryption::Errors::Decryption
          invalid!
        end
        def invalid! = raise(Domain::Services::WebhookSignature::InvalidPayload)
      end
    end
  end
end
