module Procurement
  class InventoryCatalogController < ApplicationController
    helper ProcurementHelper
    before_action { @kind = self.class::CATALOG_KIND }
    rescue_from ActionController::ParameterMissing do
      render plain: "Dữ liệu danh mục không hợp lệ", status: :bad_request
    end
    def index
      @workspace = HrmProcurement::Application::Queries::StockCatalog.new.call(actor: current_user, kind: @kind, search: params[:q], status: params[:status], page: params[:page])
      render "procurement/inventory_catalog/index"
    end
    def new
      authorize inventory_model, :create?
      @record = inventory_model.new(status: "active")
      @input = { status: "active" }
      render "procurement/inventory_catalog/form"
    end
    def edit
      load_record
      authorize @record, :update?
      @input = @record.attributes.symbolize_keys.slice(:code, :name, :unit, :status)
      render "procurement/inventory_catalog/form"
    end
    def create
      @input = HrmProcurement::Application::Requests::StockParameters.catalog(params)
      HrmProcurement::Application::Commands::SaveStockCatalog.new.call(actor: current_user, kind: @kind, attributes: @input)
      redirect_to inventory_destination, notice: I18n.t("procurement.notices.catalog_saved", locale: :vi)
    rescue HrmProcurement::Domain::Services::RequestContent::Invalid, ActiveRecord::RecordInvalid => error
      @record = inventory_model.new
      @errors = error.message
      render "procurement/inventory_catalog/form", status: :unprocessable_content
    end
    def update
      @input = HrmProcurement::Application::Requests::StockParameters.catalog(params)
      HrmProcurement::Application::Commands::SaveStockCatalog.new.call(actor: current_user, kind: @kind, id: params[:id], attributes: @input, lock_version: params[:lock_version])
      redirect_to inventory_destination, notice: I18n.t("procurement.notices.catalog_saved", locale: :vi)
    rescue HrmProcurement::Domain::Services::RequestContent::Invalid, ActiveRecord::RecordInvalid => error
      load_record
      @errors = error.message
      render "procurement/inventory_catalog/form", status: :unprocessable_content
    end
    private
    def inventory_model = @kind == :warehouse ? Warehouse : StockItem
    def inventory_destination = @kind == :warehouse ? inventory_warehouses_path : inventory_items_path
    def load_record
      @record = HrmProcurement::Application::Queries::FindStockCatalog.new.call(actor: current_user, kind: @kind, id: params[:id])
    end
  end
end
