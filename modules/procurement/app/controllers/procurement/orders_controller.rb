module Procurement
  class OrdersController < ApplicationController
    helper ProcurementHelper
    before_action :list_context
    rescue_from ActionController::ParameterMissing do
      render plain: "Dữ liệu PO không hợp lệ", status: :bad_request
    end
    rescue_from HrmProcurement::Domain::Services::RequestConflict do |error|
      render plain: error.message, status: :conflict
    end
    def index
      @workspace = HrmProcurement::Application::Queries::Orders.new.call(actor: current_user, search: params[:q], status: params[:status], page: params[:page], delivery: params[:delivery])
    end
    def show
      load_record
    end
    def new
      load_source(params[:purchase_request_id])
      return redirect_to purchase_order_path(@source[:order]) if @source[:order]
      @input = { expected_on: @source[:record].needed_on.iso8601 }
    end
    def edit
      load_record
      authorize @record, :update?
      @input = { expected_on: @record.expected_on.iso8601, price_change_reason: @record.price_change_reason,
        items: @record.lines.map { |line| { "source_line_id" => line.source_line_id.to_s, "unit_price" => line.unit_price.to_i.to_s } } }
    end
    def create
      @input = HrmProcurement::Application::Requests::OrderParameters.read(params, kind: :order)
      record = HrmProcurement::Application::Commands::CreateOrder.new.call(actor: current_user, purchase_request_id: @input[:purchase_request_id], supplier_id: @input[:supplier_id], expected_on: @input[:expected_on])
      redirect_to purchase_order_path(record, @list_filters), notice: I18n.t("procurement.notices.order_created", locale: :vi)
    rescue HrmProcurement::Domain::Services::RequestContent::Invalid, ActiveRecord::RecordInvalid => error
      load_source(@input[:purchase_request_id])
      @errors = error.message
      render :new, status: :unprocessable_content
    end
    def update
      @input = HrmProcurement::Application::Requests::OrderParameters.read(params, kind: :order)
      record = HrmProcurement::Application::Commands::UpdateOrder.new.call(actor: current_user, id: params[:id], attributes: @input, lock_version: params[:lock_version])
      redirect_to purchase_order_path(record, @list_filters), notice: I18n.t("procurement.notices.order_updated", locale: :vi)
    rescue HrmProcurement::Domain::Services::RequestContent::Invalid, ActiveRecord::RecordInvalid => error
      load_record
      @errors = error.message
      render :edit, status: :unprocessable_content
    end
    def issue
      record = HrmProcurement::Application::Commands::IssueOrder.new.call(actor: current_user, id: params[:id], lock_version: params[:lock_version])
      redirect_to purchase_order_path(record, @list_filters), notice: I18n.t("procurement.notices.order_issued", locale: :vi)
    rescue HrmProcurement::Domain::Services::RequestContent::Invalid => error
      load_record
      @errors = error.message
      render :show, status: :unprocessable_content
    end
    private
    def list_context
      @list_filters = HrmProcurement::Domain::Services::RequestFilters.read(search: params[:q], page: params[:page])
      @list_filters[:status] = Hrm::ListFilters.choice(params[:status], allowed: %w[draft issued])
      @list_filters[:delivery] = Hrm::ListFilters.choice(params[:delivery], allowed: %w[pending])
      @list_filters.compact!
    end
    def load_source(id)
      @source = HrmProcurement::Application::Queries::OrderSource.new.call(actor: current_user, id: id)
    end
    def load_record
      @detail = HrmProcurement::Application::Queries::FindOrder.new.call(actor: current_user, id: params[:id], history_page: params[:history_page])
      @record = @detail[:record]
    end
  end
end
