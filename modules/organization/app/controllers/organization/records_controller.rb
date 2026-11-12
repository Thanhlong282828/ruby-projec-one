module Organization
  class RecordsController < ApplicationController
    rescue_from ActiveRecord::RecordInvalid do |error|
      @data = HrmOrganization::Application::Queries::RecordForm.new.call(actor: current_user, resource: resource, id: params[:id])
      @data[:record] = error.record
      @definition = HrmOrganization::Domain::Resources.fetch(resource)
      render :form, status: :unprocessable_content
    end
    rescue_from ActiveRecord::RecordNotDestroyed do |error|
      redirect_to base_path, alert: error.record.errors.full_messages.to_sentence
    end
    def index
      @definition = HrmOrganization::Domain::Resources.fetch(resource)
      @data = HrmOrganization::Application::Queries::Workspace.new.call(actor: current_user, resource: resource, page: params[:page])
    end
    def show
      @definition = HrmOrganization::Domain::Resources.fetch(resource)
      @data = HrmOrganization::Application::Queries::Workspace.new.call(actor: current_user, resource: resource, id: params[:id])
      @record = @data[:record]
    end
    def new = prepare_form
    def edit = prepare_form
    def create
      record = HrmOrganization::Application::Commands::CreateRecord.new.call(actor: current_user, resource: resource, attributes: record_params)
      redirect_to "#{base_path}/#{record.id}", notice: I18n.t("hrm_quality.messages.da_tao_ban_ghi")
    end
    def update
      HrmOrganization::Application::Commands::UpdateRecord.new.call(actor: current_user, resource: resource, id: params[:id], attributes: record_params)
      redirect_to "#{base_path}/#{params[:id]}", notice: I18n.t("hrm_quality.messages.da_cap_nhat")
    end
    def destroy
      HrmOrganization::Application::Commands::DeleteRecord.new.call(actor: current_user, resource: resource, id: params[:id])
      redirect_to base_path, notice: I18n.t("hrm_quality.messages.da_xoa_ban_ghi")
    end
    def export
      csv = HrmOrganization::Application::Queries::ExportRecords.new.call(actor: current_user, resource: resource)
      send_data csv, filename: "#{resource}-#{Date.current}.csv", type: "text/csv; charset=utf-8"
    end
    private
    def resource = request.path_parameters.fetch(:resource)
    def base_path = HrmOrganization::Domain::Resources.path(resource)
    def record_params = HrmOrganization::Application::Requests::RecordRequest.read(params, resource: resource)
    def prepare_form
      @definition = HrmOrganization::Domain::Resources.fetch(resource)
      @data = HrmOrganization::Application::Queries::RecordForm.new.call(actor: current_user, resource: resource, id: params[:id])
      render :form
    end
  end
end
