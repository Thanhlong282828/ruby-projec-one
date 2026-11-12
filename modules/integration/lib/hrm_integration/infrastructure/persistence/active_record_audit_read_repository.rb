module HrmIntegration
  module Infrastructure
    module Persistence
      class ActiveRecordAuditReadRepository < Domain::Repositories::AuditReadRepositoryInterface
        SOURCE_PREFIXES = { "IntegrationConnection" => "/integration/connections", "IntegrationWebhook" => "/integration/inbox", "IntegrationDelivery" => "/integration/outbound" }.freeze
        SOURCE_MODELS = { "IntegrationConnection" => ::IntegrationConnection, "IntegrationWebhook" => ::IntegrationWebhook,
          "IntegrationDelivery" => ::IntegrationDelivery, "IntegrationDeliveryAttempt" => ::IntegrationDeliveryAttempt }.freeze
        # Metadata is projected explicitly. Never serialize the audit row or decrypt payload/secret for this portal.
        def workspace(actor:, filters:)
          Pundit.authorize(actor, [ :integration, ::AuditLog ], :index?)
          scope = Pundit.policy_scope!(actor, [ :integration, ::AuditLog ])
            .where(action: Domain::Services::AuditFilters::ACTIONS)
            .where(created_at: filters.from.beginning_of_day...filters.to.next_day.beginning_of_day)
          scope = scope.where(record_type: Domain::Services::AuditFilters::RESOURCES.fetch(filters.resource)) if filters.resource != "all"
          scope = scope.where(record_id: filters.record_id) if filters.record_id
          counts = scope.group(:action).count.slice(*Domain::Services::AuditFilters::ACTIONS)
          scope = scope.where(action: filters.operation) if filters.operation != "all"
          scope = scope.where(id: ...filters.before) if filters.before
          logs = scope.order(id: :desc).select(:id, :action, :record_type, :record_id, :actor_id, :metadata, :created_at).limit(26).to_a
          page = logs.first(25)
          sources = source_map(actor, page)
          { records: page.map { |entry| project(entry, sources) }, counts: counts, filters: filters.parameters,
           timezone: Time.zone.name, next_before: logs.length > 25 ? page.last.id : nil, before: filters.before }
        end
        private
        def source_map(actor, logs)
          logs.group_by(&:record_type).each_with_object({}) do |(type, entries), result|
            model = SOURCE_MODELS[type]
            next unless model
            ids = entries.map(&:record_id)
            rows = Pundit.policy_scope!(actor, type == "IntegrationDeliveryAttempt" ? ::IntegrationDelivery : model)
            if type == "IntegrationDeliveryAttempt"
              ::IntegrationDeliveryAttempt.where(company_id: actor.company_id, id: ids, integration_delivery_id: rows.select(:id))
                .select(:id, :integration_delivery_id, :sequence, :http_status, :outcome).each do |attempt|
                result[[ type, attempt.id ]] = { url: "/integration/outbound/#{attempt.integration_delivery_id}",
                  attempt: { sequence: attempt.sequence, http_status: attempt.http_status, outcome: attempt.outcome } }
              end
            else
              prefix = SOURCE_PREFIXES.fetch(type)
              rows.where(id: ids).pluck(:id).each { |id| result[[ type, id ]] = { url: "#{prefix}/#{id}" } }
            end
          end
        end
        def project(entry, sources)
          model = SOURCE_MODELS[entry.record_type]
          metadata = entry.metadata
          fields = metadata.is_a?(Hash) ? metadata["changed_fields"] : nil
          # Legacy or imported metadata may contain arbitrary data: return column NAMES only, never values.
          fields = fields.is_a?(Array) && model ? fields.select { |field| field.is_a?(String) && model.column_names.include?(field) }.uniq : []
          source = sources.fetch([ entry.record_type, entry.record_id ], {})
          { id: entry.id, action: entry.action, record_type: entry.record_type, record_id: entry.record_id,
           actor_id: entry.actor_id, changed_fields: fields, occurred_at: entry.created_at,
           source_url: source[:url], attempt: source[:attempt] }
        end
      end
    end
  end
end
