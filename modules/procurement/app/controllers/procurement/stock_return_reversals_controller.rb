module Procurement
  class StockReturnReversalsController < ApplicationController
    helper ProcurementHelper
    rescue_from HrmProcurement::Domain::Services::RequestConflict do |error|
      render plain: error.message, status: :conflict
    end
    rescue_from ActionController::ParameterMissing do
      render plain: "Dữ liệu đảo phiếu không hợp lệ", status: :bad_request
    end
    def index
      @workspace = HrmProcurement::Application::Queries::StockReturnReversals.new.call(actor: current_user, search: params[:q], page: params[:page])
    end
    def show
      @detail = HrmProcurement::Application::Queries::FindStockReturnReversal.new.call(actor: current_user, id: params[:id])
      @record = @detail[:record]
    end
    def new
      @input = { idempotency_key: SecureRandom.uuid }
      load_source(params[:stock_return_id])
    end
    def create
      @input = HrmProcurement::Application::Requests::ReversalParameters.posting(params)
      record = HrmProcurement::Application::Commands::PostStockReturnReversal.new.call(actor: current_user, id: @input[:stock_return_id], attributes: @input)
      redirect_to stock_return_reversal_path(record), notice: I18n.t("procurement.notices.stock_return_reversed", locale: :vi)
    rescue HrmProcurement::Domain::Services::RequestContent::Invalid, ActiveRecord::RecordInvalid => error
      load_source(@input[:stock_return_id])
      @errors = error.message
      render :new, status: :unprocessable_content
    end
    private
    def load_source(id)
      @detail = HrmProcurement::Application::Queries::StockReturnReversalSource.new.call(actor: current_user, id: id)
      @record = @detail[:record]
    end
  end
end
