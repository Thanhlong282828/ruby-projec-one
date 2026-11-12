module HrmIntegration
  module Application
    module Requests
      class ConnectionParameters
        def self.read(params)
          input = params.require(:integration_connection)
          raise ActionController::ParameterMissing, :integration_connection unless input.is_a?(ActionController::Parameters)
          allowed = input.permit(:code, :name).to_h.symbolize_keys
          raise ActionController::ParameterMissing, :integration_connection unless allowed.values.all?(String)
          allowed
        end
      end
    end
  end
end
