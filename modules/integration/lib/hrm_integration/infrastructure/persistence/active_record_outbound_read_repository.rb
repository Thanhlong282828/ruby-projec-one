module HrmIntegration
  module Infrastructure
    module Persistence
      class ActiveRecordOutboundReadRepository < Domain::Repositories::OutboundReadRepositoryInterface
        def payroll_workspace(actor:, export_id:)
          Pundit.authorize(actor, ::IntegrationDelivery, :create?)
          Pundit.authorize(actor, ::PayrollExport, :notify?)
          source = Pundit.policy_scope!(actor, ::PayrollExport).select(::PayrollExport::METADATA_COLUMNS)
            .find(HrmPayroll::Domain::Services::ExportFilters.id!(export_id))
          { source: source,
           connections: Pundit.policy_scope!(actor, ::IntegrationConnection).where(active: true).order(:code).limit(200).to_a,
           targets: Http::OutboundTransport.targets(company_id: actor.company_id).keys.sort,
           deliveries: Pundit.policy_scope!(actor, ::IntegrationDelivery).where(payroll_export_id: source.id).order(id: :desc).limit(25).to_a }
        end
        def workspace(actor:, page: 1, status: nil)
          page = 1 if page.nil? || page == ""
          valid = (page.is_a?(Integer) && page.between?(1, 10_000)) || (page.is_a?(String) && /\A[1-9][0-9]{0,4}\z/.match?(page) && page.to_i <= 10_000)
          raise Domain::Services::WebhookSignature::InvalidPayload unless valid && (status.nil? || status == "" || %w[queued retry_wait delivered dead_letter blocked].include?(status))
          scope = Pundit.policy_scope!(actor, ::IntegrationDelivery)
          filtered = status.present? ? scope.where(status: status) : scope
          rows = filtered.includes(:integration_connection).order(id: :desc).limit(26).offset((page.to_i - 1) * 25).to_a
          { records: rows.first(25), counts: scope.group(:status).count, next_page: rows.size > 25, page: page.to_i, status: status,
           connections: Pundit.policy_scope!(actor, ::IntegrationConnection).where(active: true).order(:code).limit(200).to_a,
           targets: Http::OutboundTransport.targets(company_id: actor.company_id).keys.sort }
        end
        def find!(actor:, id:, payload: false)
          raise ActiveRecord::RecordNotFound unless (id.is_a?(Integer) && id.positive?) || (id.is_a?(String) && /\A[1-9][0-9]{0,17}\z/.match?(id))
          record = Pundit.policy_scope!(actor, ::IntegrationDelivery).includes(:integration_connection).find(id)
          Pundit.authorize(actor, record, payload ? :payload? : :show?)
          { record: record, attempts: record.integration_delivery_attempts.order(:id).limit(55).to_a, body: payload ? record.payload : nil }
        end
      end
    end
  end
end
