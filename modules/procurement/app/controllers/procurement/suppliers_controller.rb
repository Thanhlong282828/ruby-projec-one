module Procurement
  class SuppliersController < ApplicationController
    rescue_from ActionController::ParameterMissing do
      render plain: "Dữ liệu nhà cung cấp không hợp lệ", status: :bad_request
    end
    def index
      @workspace = HrmProcurement::Application::Queries::Suppliers.new.call(actor: current_user, search: params[:q], status: params[:status], page: params[:page])
    end
    def new
      authorize ProcurementSupplier, :create?
      @record = ProcurementSupplier.new(status: "active")
      @input = { status: "active" }
    end
    def edit
      load_record
      authorize @record, :update?
      @input = @record.attributes.symbolize_keys.slice(:code, :name, :status)
    end
    def create
      @input = HrmProcurement::Application::Requests::OrderParameters.read(params, kind: :supplier)
      HrmProcurement::Application::Commands::SaveSupplier.new.call(actor: current_user, attributes: @input)
      redirect_to procurement_suppliers_path, notice: I18n.t("procurement.notices.supplier_saved", locale: :vi)
    rescue HrmProcurement::Domain::Services::RequestContent::Invalid, ActiveRecord::RecordInvalid => error
      @record = ProcurementSupplier.new
      @errors = error.message
      render :new, status: :unprocessable_content
    end
    def update
      @input = HrmProcurement::Application::Requests::OrderParameters.read(params, kind: :supplier)
      HrmProcurement::Application::Commands::SaveSupplier.new.call(actor: current_user, id: params[:id], attributes: @input, lock_version: params[:lock_version])
      redirect_to procurement_suppliers_path, notice: I18n.t("procurement.notices.supplier_saved", locale: :vi)
    rescue HrmProcurement::Domain::Services::RequestContent::Invalid, ActiveRecord::RecordInvalid => error
      load_record
      @errors = error.message
      render :edit, status: :unprocessable_content
    end
    private
    def load_record
      @record = HrmProcurement::Application::Queries::FindSupplier.new.call(actor: current_user, id: params[:id])
    end
  end
end
