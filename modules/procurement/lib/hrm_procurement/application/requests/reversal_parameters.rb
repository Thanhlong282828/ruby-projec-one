module HrmProcurement
  module Application
    module Requests
      class ReversalParameters
        def self.posting(params)
          StockParameters.root(params, :stock_return_reversal).permit(:stock_return_id, :idempotency_key, :reason).to_h.symbolize_keys
        end
      end
    end
  end
end
