module HrmProcurement
  module Application
    module Requests
      class StockParameters
        def self.root(params, key)
          input = params.require(key)
          raise ActionController::ParameterMissing, key unless input.is_a?(ActionController::Parameters)
          input
        end
        def self.catalog(params)
          root(params, :inventory_catalog).permit(:code, :name, :unit, :status).to_h.symbolize_keys
        end
        def self.posting(params)
          root(params, :stock_receipt).permit(:goods_receipt_id, :warehouse_id, items: [ :goods_receipt_line_id, :stock_item_id ]).to_h.symbolize_keys
        end
      end
    end
  end
end
