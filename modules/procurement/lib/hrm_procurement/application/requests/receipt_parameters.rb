module HrmProcurement
  module Application
    module Requests
      class ReceiptParameters
        def self.read(params)
          input = params.require(:goods_receipt)
          raise ActionController::ParameterMissing, :goods_receipt unless input.is_a?(ActionController::Parameters)
          input.permit(:purchase_order_id, :received_on, :delivery_reference, :idempotency_key, items: [ :purchase_order_line_id, :quantity ]).to_h.symbolize_keys
        end
      end
    end
  end
end
