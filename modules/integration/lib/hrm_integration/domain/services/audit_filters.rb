module HrmIntegration
  module Domain
    module Services
      class AuditFilters
        RESOURCES = { "connection" => "IntegrationConnection", "inbound" => "IntegrationWebhook",
          "outbound" => "IntegrationDelivery", "attempt" => "IntegrationDeliveryAttempt" }.freeze
        ACTIONS = %w[created updated deleted].freeze
        attr_reader :from, :to, :resource, :operation, :record_id, :before

        def initialize(from: nil, to: nil, resource: nil, operation: nil, record_id: nil, before: nil)
          @from = date!(from, Date.current - 29)
          @to = date!(to, Date.current)
          invalid! unless @from <= @to && @to <= Date.current && (@to - @from).to_i < 93
          @resource = choice!(resource, RESOURCES.keys)
          @operation = choice!(operation, ACTIONS)
          @record_id = id!(record_id)
          @before = id!(before)
          invalid! if @record_id && @resource == "all"
          freeze
        end
        def parameters
          { from: from.iso8601, to: to.iso8601, resource: resource, operation: operation, record_id: record_id }.compact
        end
        private
        def date!(value, fallback)
          return fallback if value.nil? || value == ""
          invalid! unless value.is_a?(String) && /\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/.match?(value)
          Date.iso8601(value)
        rescue Date::Error
          invalid!
        end
        def choice!(value, choices)
          return "all" if value.nil? || value == "" || value == "all"
          invalid! unless value.is_a?(String) && choices.include?(value)
          value
        end
        def id!(value)
          return nil if value.nil? || value == ""
          valid = (value.is_a?(Integer) && value.positive?) || (value.is_a?(String) && /\A[1-9][0-9]{0,18}\z/.match?(value))
          invalid! unless valid && value.to_i <= 9_223_372_036_854_775_807
          value.to_i
        end
        def invalid! = raise(WebhookSignature::InvalidPayload)
      end
    end
  end
end
