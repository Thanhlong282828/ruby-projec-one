module Procurement
  class ReceiptsController < ApplicationController
    helper ProcurementHelper
    rescue_from HrmProcurement::Domain::Services::RequestConflict do |error|
      render plain: error.message, status: :conflict
    end
    rescue_from ActionController::ParameterMissing do
      render plain: "Dữ liệu nhận hàng không hợp lệ", status: :bad_request
    end
    def index
      @workspace = HrmProcurement::Application::Queries::Receipts.new.call(actor: current_user, search: params[:q], page: params[:page])
    end
    def show
      @detail = HrmProcurement::Application::Queries::FindReceipt.new.call(actor: current_user, id: params[:id])
      @record = @detail[:record]
    end
    def new
      @input = { received_on: Date.current.iso8601, idempotency_key: SecureRandom.uuid }
      load_source(params[:purchase_order_id])
    end
    def create
      @input = HrmProcurement::Application::Requests::ReceiptParameters.read(params)
      record = HrmProcurement::Application::Commands::ReceiveOrder.new.call(actor: current_user, id: @input[:purchase_order_id], attributes: @input)
      redirect_to goods_receipt_path(record), notice: I18n.t("procurement.notices.receipt_created", locale: :vi)
    rescue HrmProcurement::Domain::Services::RequestContent::Invalid, ActiveRecord::RecordInvalid => error
      load_source(@input[:purchase_order_id])
      @errors = error.message
      render :new, status: :unprocessable_content
    end
    private
    def load_source(id)
      @detail = HrmProcurement::Application::Queries::ReceivingSource.new.call(actor: current_user, id: id)
      @record = @detail[:record]
    end
  end
end
