module HrmIntegration
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        def count(actor:) = Pundit.policy_scope!(actor, ::IntegrationWebhook).count
        def workspace(actor:, page: 1, status: nil)
          page = page_number!(page)
          raise Domain::Services::WebhookSignature::InvalidPayload unless status.nil? || status == "" || %w[received acknowledged rejected].include?(status)
          scope = Pundit.policy_scope!(actor, ::IntegrationWebhook)
          filtered = status.present? ? scope.where(status: status) : scope
          records = filtered.includes(:integration_connection).order(id: :desc).limit(26).offset((page - 1) * 25).to_a
          {
            connections: Pundit.policy_scope!(actor, ::IntegrationConnection).order(:code).limit(200).to_a,
            counts: scope.group(:status).count, webhooks: records.first(25), page: page,
            next_page: records.size > 25, status: status
          }
        end
        def connection!(actor:, id:) = Pundit.policy_scope!(actor, ::IntegrationConnection).find(id!(id))
        def webhook!(actor:, id:) = Pundit.policy_scope!(actor, ::IntegrationWebhook).includes(:integration_connection).find(id!(id))
        def payload!(actor:, id:)
          record = webhook!(actor: actor, id: id)
          Pundit.authorize(actor, record, :payload?)
          { body: record.payload, note: record.review_note, id: record.id }
        end
        private
        def id!(id)
          raise ActiveRecord::RecordNotFound unless (id.is_a?(Integer) && id.positive?) || (id.is_a?(String) && /\A[1-9][0-9]{0,17}\z/.match?(id))
          id
        end
        def page_number!(value)
          return 1 if value.nil? || value == ""
          valid = (value.is_a?(Integer) && value.between?(1, 10_000)) || (value.is_a?(String) && /\A[1-9][0-9]{0,4}\z/.match?(value) && value.to_i <= 10_000)
          raise Domain::Services::WebhookSignature::InvalidPayload unless valid
          value.to_i
        end
      end
    end
  end
end
