module HrmIntegration
  module Application
    module Requests
      class AuditParameters
        KEYS = %i[from to resource operation record_id before].freeze
        def self.read(params)
          # Preserve malformed types so validation rejects them rather than silently broadening a query.
          KEYS.index_with { |key| params[key] }
        end
      end
    end
  end
end
