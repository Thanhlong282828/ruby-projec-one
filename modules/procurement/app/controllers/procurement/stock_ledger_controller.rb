module Procurement
  class StockLedgerController < ApplicationController
    def index
      @workspace = HrmProcurement::Application::Queries::StockLedger.new.call(actor: current_user,
        warehouse_id: params[:warehouse_id], stock_item_id: params[:stock_item_id], page: params[:page])
    end
  end
end
