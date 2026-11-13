module Procurement
  class StockReturnsController < ApplicationController
    helper ProcurementHelper
    rescue_from HrmProcurement::Domain::Services::RequestConflict do |error|
      render plain: error.message, status: :conflict
    end
    rescue_from ActionController::ParameterMissing do
      render plain: "Dữ liệu trả hàng không hợp lệ", status: :bad_request
    end
    def index
      @workspace = HrmProcurement::Application::Queries::StockReturns.new.call(actor: current_user, search: params[:q], page: params[:page])
    end
    def show
      @detail = HrmProcurement::Application::Queries::FindStockReturn.new.call(actor: current_user, id: params[:id])
      @record = @detail[:record]
    end
    def new
      @input = { idempotency_key: SecureRandom.uuid }
      load_source(params[:stock_receipt_id])
    end
    def create
      @input = HrmProcurement::Application::Requests::ReturnParameters.posting(params)
      record = HrmProcurement::Application::Commands::PostStockReturn.new.call(actor: current_user, id: @input[:stock_receipt_id], attributes: @input)
      redirect_to stock_return_path(record), notice: I18n.t("procurement.notices.stock_returned", locale: :vi)
    rescue HrmProcurement::Domain::Services::RequestContent::Invalid, ActiveRecord::RecordInvalid => error
      load_source(@input[:stock_receipt_id])
      @errors = error.message
      render :new, status: :unprocessable_content
    end
    private
    def load_source(id)
      @detail = HrmProcurement::Application::Queries::StockReturnSource.new.call(actor: current_user, id: id)
      @record = @detail[:record]
    end
  end
end
