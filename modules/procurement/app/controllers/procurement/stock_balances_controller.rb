module Procurement
  class StockBalancesController < ApplicationController
    def index
      @workspace = HrmProcurement::Application::Queries::StockBalances.new.call(actor: current_user, warehouse_id: params[:warehouse_id], page: params[:page])
    end
  end
end
