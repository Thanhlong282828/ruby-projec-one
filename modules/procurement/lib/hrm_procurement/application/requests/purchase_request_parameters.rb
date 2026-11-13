module HrmProcurement
  module Application
    module Requests
      class PurchaseRequestParameters
        def self.read(params)
          input = params.require(:purchase_request)
          raise ActionController::ParameterMissing, :purchase_request unless input.is_a?(ActionController::Parameters)
          input.permit(:title, :purpose, :needed_on, items: [ :description, :quantity, :unit, :estimated_unit_price ]).to_h.symbolize_keys
        end
      end
    end
  end
end
