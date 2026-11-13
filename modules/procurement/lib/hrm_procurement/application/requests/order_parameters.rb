module HrmProcurement
  module Application
    module Requests
      class OrderParameters
        def self.read(params, kind:)
          root = kind == :supplier ? :supplier : :purchase_order
          input = params.require(root)
          raise ActionController::ParameterMissing, root unless input.is_a?(ActionController::Parameters)
          fields = kind == :supplier ? [ :code, :name, :status ] : [ :purchase_request_id, :supplier_id, :expected_on, :price_change_reason, { items: [ :source_line_id, :unit_price ] } ]
          input.permit(*fields).to_h.symbolize_keys
        end
      end
    end
  end
end
