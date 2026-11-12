module HrmIntegration
  module Infrastructure
    module Persistence
      class ActiveRecordDeliveryRepository < Domain::Repositories::DeliveryRepositoryInterface
        def initialize(transport: Http::OutboundTransport.new, source_repository: Hrm::Container.resolve(HrmPayroll::Domain::Repositories::ExportSourceRepositoryInterface))
          super()
          @transport = transport
          @source_repository = source_repository
        end
        def due_ids
          ::IntegrationDelivery.where(status: %w[queued retry_wait]).where(available_at: ..Time.current).order(:available_at, :id).limit(100).pluck(:id)
        end
        def deliver!(id:)
          record = ::IntegrationDelivery.find_by(id: id)
          return unless record
          # Resolve association before opening the transaction: do not establish a
          # MySQL repeatable-read snapshot before waiting for the connection lock.
          connection = record.integration_connection
          record.with_lock do
            return unless %w[queued retry_wait].include?(record.status) && record.available_at <= Time.current
            connection.with_lock do
              # Acquire every contended source lock before the first consistent
              # actor/grant read, preserving freshness under MySQL REPEATABLE READ.
              @source_repository.lock_for_delivery!(company_id: record.company_id, id: record.payroll_export_id) if record.payroll_export_id
              actor = record.requested_by.reload
              authorized = ActiveRecord::Base.uncached { connection.active? && actor.company_id == record.company_id && Pundit.policy!(actor, record).create? }
              unless authorized
                block!(record)
                return
              end
              begin
                body = Domain::Services::PayrollNotification.verify!(actor: actor, record: record, source_repository: @source_repository)
              rescue Domain::Services::WebhookSignature::InvalidPayload, ActiveRecord::Encryption::Errors::Decryption, ActiveRecord::RecordNotFound, Pundit::NotAuthorizedError
                # Commit quarantine + audit/outbox, without HTTP or an invented network attempt.
                block!(record)
                return
              end
              # Lock bounds duplicate workers; remote side MUST deduplicate event_id for crash recovery.
              start = Time.current
              result = @transport.call(company_id: record.company_id, target_key: record.target_key, body: body, event_id: record.event_id, secret: connection.signing_secret)
              count = record.attempt_count + 1
              cycle_count = record.cycle_attempt_count + 1
              permanent = result[:code] && result[:code].between?(400, 499) && [ 408, 429 ].exclude?(result[:code])
              status = result[:outcome] == "delivered" ? "delivered" : (permanent || cycle_count >= 5 ? "dead_letter" : "retry_wait")
              Current.set(user: nil) do
                record.integration_delivery_attempts.create!(company_id: record.company_id, sequence: count, http_status: result[:code],
                  outcome: result[:outcome], started_at: start, completed_at: Time.current)
                record.update!(attempt_count: count, cycle_attempt_count: cycle_count, status: status, delivered_at: status == "delivered" ? Time.current : nil,
                  available_at: Time.current + [ 60 * (2 ** (count - 1)), 3600 ].min.seconds)
              end
            end
          end
        end
        private
        def block!(record)
          # This locked instance has no mutations except the quarantine status.
          # Rails' automatic encrypted-column length validator decrypts even on
          # status-only updates. Skip validation ONLY here to preserve corrupt bytes;
          # retain row lock, optimistic lock, DB CHECKs and audit/outbox callbacks.
          record.status = "blocked"
          raise ActiveRecord::ReadOnlyRecord unless record.changes.keys == [ "status" ]
          Current.set(user: nil) { record.save!(validate: false) }
        end
      end
    end
  end
end
