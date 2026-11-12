module HrmIntegration
  module Infrastructure
    module Persistence
      class ActiveRecordPayrollBridgeRepository < Domain::Repositories::PayrollBridgeRepositoryInterface
        def initialize(source_repository: Hrm::Container.resolve(HrmPayroll::Domain::Repositories::ExportSourceRepositoryInterface))
          super()
          @source_repository = source_repository
        end
        def enqueue!(actor:, export_id:, connection_id:, target_key:)
          Pundit.authorize(actor, ::IntegrationDelivery, :create?)
          Pundit.authorize(actor, ::PayrollExport, :notify?)
          raise Domain::Services::WebhookSignature::InvalidPayload unless target_key.is_a?(String) && Http::OutboundTransport.targets(company_id: actor.company_id).key?(target_key)
          source_id = HrmPayroll::Domain::Services::ExportFilters.id!(export_id)
          connection = Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface).connection!(actor: actor, id: connection_id)
          connection.with_lock do
            @source_repository.lock_for_delivery!(company_id: actor.company_id, id: source_id)
            ActiveRecord::Base.uncached { Pundit.authorize(actor, ::IntegrationDelivery, :create?) }
            raise Domain::Services::WebhookSignature::InvalidPayload unless connection.active?
            @source_repository.with_verified_descriptor(actor: actor, id: source_id) do |descriptor|
              key = "payroll-v1:" + Digest::SHA256.hexdigest([ actor.company_id, source_id, connection.id, target_key ].to_json)
              body = Domain::Services::PayrollNotification.body(descriptor)
              digest = Digest::SHA256.hexdigest(body)
              existing = ::IntegrationDelivery.find_by(company_id: actor.company_id, idempotency_key: key)
              if existing
                valid = existing.payroll_export_id == source_id && existing.integration_connection_id == connection.id && existing.target_key == target_key && ActiveSupport::SecurityUtils.secure_compare(existing.body_digest, digest)
                valid &&= ActiveSupport::SecurityUtils.secure_compare(existing.payload, body)
                raise Domain::Services::WebhookSignature::Conflict unless valid
                return existing
              end
              Current.set(user: actor) do
                ::IntegrationDelivery.create!(company_id: actor.company_id, integration_connection: connection, requested_by: actor,
                  payroll_export_id: source_id, target_key: target_key, payload: body, body_digest: digest, event_id: SecureRandom.uuid,
                  idempotency_key: key, status: "queued", available_at: Time.current)
              end
            end
          end
        rescue ActiveRecord::Encryption::Errors::Decryption
          raise HrmPayroll::Domain::Services::PayrollCsv::IntegrityError
        rescue ActiveRecord::RecordNotUnique
          raise Domain::Services::WebhookSignature::Conflict
        end
      end
    end
  end
end
