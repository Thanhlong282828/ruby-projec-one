module Integration
  class DeliveriesController < ApplicationController
    helper IntegrationDeliveryHelper
    rescue_from HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload, ActionController::ParameterMissing do
      render plain: "Dữ liệu gửi không hợp lệ.", status: :bad_request
    end
    rescue_from HrmIntegration::Domain::Services::WebhookSignature::Conflict do
      render plain: "Idempotency key đã dùng cho nội dung khác.", status: :conflict
    end
    rescue_from HrmIntegration::Infrastructure::Http::OutboundTransport::Unavailable do
      render plain: "Cấu hình đích gửi chưa hợp lệ.", status: :service_unavailable
    end
    def index
      @workspace = HrmIntegration::Application::Queries::OutboundWorkspace.new.call(actor: current_user, page: params[:page], status: params[:status])
    end
    def show
      @delivery = HrmIntegration::Application::Queries::FindDelivery.new.call(actor: current_user, id: params[:id])
    end
    def payload
      @delivery = HrmIntegration::Application::Queries::FindDelivery.new.call(actor: current_user, id: params[:id], payload: true)
      render :show
    end
    def create
      record = HrmIntegration::Application::Commands::QueueDelivery.new.call(actor: current_user, **delivery_parameters)
      redirect_to "/integration/outbound/#{record.id}", notice: I18n.t("hrm_quality.messages.da_luu_hang_doi_mysql_scheduler_se_chuyen_sang_sidekiq")
    end
    def retry
      record = HrmIntegration::Application::Commands::RetryDelivery.new.call(actor: current_user, id: params[:id], lock_version: params[:lock_version])
      redirect_to "/integration/outbound/#{record.id}", notice: I18n.t("hrm_quality.messages.da_xep_hang_lai_giu_nguyen_event_id_va_lich_su")
    end
    private
    def delivery_parameters
      HrmIntegration::Application::Requests::DeliveryParameters.read(params)
    end
  end
end
