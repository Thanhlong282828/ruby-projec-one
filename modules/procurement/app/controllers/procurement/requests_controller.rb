module Procurement
  class RequestsController < ApplicationController
    helper ProcurementHelper
    before_action :list_context
    rescue_from ActionController::ParameterMissing do
      render plain: "Dữ liệu yêu cầu mua không hợp lệ", status: :bad_request
    end
    rescue_from HrmProcurement::Domain::Services::RequestConflict do |error|
      render plain: error.message, status: :conflict
    end
    def index
      @workspace = HrmProcurement::Application::Queries::Workspace.new.call(actor: current_user,
        search: params[:q], status: params[:status], view: params[:view], page: params[:page])
    end
    def show
      load_record
    end
    def new
      authorize PurchaseRequest, :create?
      @record = PurchaseRequest.new
      @input = { needed_on: (Date.current + 7).iso8601, items: [] }
    end
    def edit
      load_record
      authorize @record, :update?
      @input = procurement_form_input(@record)
    end
    def create
      @input = HrmProcurement::Application::Requests::PurchaseRequestParameters.read(params)
      record = HrmProcurement::Application::Commands::CreateRequest.new.call(actor: current_user, attributes: @input)
      redirect_to purchase_request_path(record, @list_filters), notice: I18n.t("procurement.notices.created", locale: :vi)
    rescue HrmProcurement::Domain::Services::RequestContent::Invalid, ActiveRecord::RecordInvalid => error
      @record = PurchaseRequest.new
      @errors = error.message
      render :new, status: :unprocessable_content
    end
    def update
      @input = HrmProcurement::Application::Requests::PurchaseRequestParameters.read(params)
      record = HrmProcurement::Application::Commands::UpdateRequest.new.call(actor: current_user, id: params[:id], attributes: @input, lock_version: params[:lock_version])
      redirect_to purchase_request_path(record, @list_filters), notice: I18n.t("procurement.notices.updated", locale: :vi)
    rescue HrmProcurement::Domain::Services::RequestContent::Invalid, ActiveRecord::RecordInvalid => error
      load_record
      @errors = error.message
      render :edit, status: :unprocessable_content
    end
    def submit
      record = HrmProcurement::Application::Commands::SubmitRequest.new.call(actor: current_user, id: params[:id], lock_version: params[:lock_version])
      redirect_to purchase_request_path(record, @list_filters), notice: I18n.t("procurement.notices.submitted", locale: :vi)
    end
    def decision
      record = HrmProcurement::Application::Commands::DecideRequest.new.call(actor: current_user, id: params[:id],
        decision: params[:decision], reason: params[:reason], lock_version: params[:lock_version])
      redirect_to purchase_request_path(record, @list_filters), notice: I18n.t("procurement.notices.decided", locale: :vi)
    rescue HrmProcurement::Domain::Services::RequestContent::Invalid => error
      load_record
      @errors = error.message
      render :show, status: :unprocessable_content
    end
    private
    def load_record
      @detail = HrmProcurement::Application::Queries::FindRequest.new.call(actor: current_user, id: params[:id], history_page: params[:history_page])
      @record = @detail.fetch(:record)
    end
    def list_context
      @list_filters = HrmProcurement::Domain::Services::RequestFilters.read(search: params[:q], status: params[:status], view: params[:view], page: params[:page])
    end
    def procurement_form_input(record)
      { title: record.title, purpose: record.purpose, needed_on: record.needed_on.iso8601,
        items: record.lines.map { |line| { "description" => line.description, "quantity" => line.quantity.to_s("F"), "unit" => line.unit, "estimated_unit_price" => line.estimated_unit_price.to_i.to_s } } }
    end
  end
end
