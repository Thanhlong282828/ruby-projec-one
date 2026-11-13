module HrmProcurement
  module Application
    module Requests
      class ReturnParameters
        def self.posting(params)
          StockParameters.root(params, :stock_return).permit(:stock_receipt_id, :idempotency_key, :reason, items: [ :stock_movement_id, :quantity ]).to_h.symbolize_keys
        end
      end
    end
  end
end
