module HrmIntegration
  module Application
    module Requests
      class DeliveryParameters
        def self.read(params)
          data = params.require(:delivery)
          raise ActionController::ParameterMissing, :delivery unless data.is_a?(ActionController::Parameters)
          allowed = data.permit(:connection_id, :target_key, :body, :idempotency_key).to_h.symbolize_keys
          { connection_id: allowed[:connection_id], target_key: allowed[:target_key], body: allowed[:body], idempotency_key: allowed[:idempotency_key] }
        end
      end
    end
  end
end
