module Procurement
  class StockReceiptsController < ApplicationController
    helper ProcurementHelper
    rescue_from HrmProcurement::Domain::Services::RequestConflict do |error|
      render plain: error.message, status: :conflict
    end
    rescue_from ActionController::ParameterMissing do
      render plain: "Dữ liệu nhập kho không hợp lệ", status: :bad_request
    end
    def index
      @workspace = HrmProcurement::Application::Queries::StockReceipts.new.call(actor: current_user, search: params[:q], page: params[:page])
    end
    def pending
      @workspace = HrmProcurement::Application::Queries::PendingStockReceipts.new.call(actor: current_user, search: params[:q], page: params[:page])
    end
    def show
      @detail = HrmProcurement::Application::Queries::FindStockReceipt.new.call(actor: current_user, id: params[:id])
      @record = @detail[:record]
    end
    def new
      @input = {}
      load_source(params[:goods_receipt_id])
      redirect_to stock_receipt_path(@detail[:existing]) if @detail[:existing]
    end
    def create
      @input = HrmProcurement::Application::Requests::StockParameters.posting(params)
      record = HrmProcurement::Application::Commands::PostStockReceipt.new.call(actor: current_user, id: @input[:goods_receipt_id], attributes: @input)
      redirect_to stock_receipt_path(record), notice: I18n.t("procurement.notices.stock_posted", locale: :vi)
    rescue HrmProcurement::Domain::Services::RequestContent::Invalid, ActiveRecord::RecordInvalid => error
      load_source(@input[:goods_receipt_id])
      @errors = error.message
      render :new, status: :unprocessable_content
    end
    private
    def load_source(id)
      @detail = HrmProcurement::Application::Queries::StockSource.new.call(actor: current_user, id: id, item_search: params[:item_q], warehouse_search: params[:warehouse_q])
      @record = @detail[:record]
    end
  end
end
