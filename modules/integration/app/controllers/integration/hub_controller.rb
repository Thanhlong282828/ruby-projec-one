module Integration
  class HubController < ApplicationController
    helper IntegrationHubHelper
    rescue_from ActiveRecord::RecordInvalid do |error|
      render plain: error.record.errors.full_messages.join("; "), status: :unprocessable_content
    end
    rescue_from ActiveRecord::RecordNotUnique do
      render plain: "Mã kết nối đã tồn tại.", status: :conflict
    end
    rescue_from ActionController::ParameterMissing, HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload do
      render plain: "Dữ liệu không hợp lệ.", status: :bad_request
    end
    def index
      @workspace = HrmIntegration::Application::Queries::Workspace.new.call(actor: current_user, page: params[:page], status: params[:status])
    end
    def new
      authorize IntegrationConnection, :create?
    end
    def create
      result = HrmIntegration::Application::Commands::CreateConnection.new.call(actor: current_user, attributes: HrmIntegration::Application::Requests::ConnectionParameters.read(params))
      @connection, @secret = result.values_at(:record, :secret)
      render :secret, status: :created
    end
    def connection
      @connection = HrmIntegration::Application::Queries::FindConnection.new.call(actor: current_user, id: params[:id])
    end
    def toggle
      record = HrmIntegration::Application::Commands::ToggleConnection.new.call(actor: current_user, id: params[:id], active: params[:active], lock_version: params[:lock_version])
      redirect_to "/integration/connections/#{record.id}", notice: I18n.t("hrm_quality.messages.da_cap_nhat_ket_noi")
    end
    def rotate
      result = HrmIntegration::Application::Commands::RotateConnectionSecret.new.call(actor: current_user, id: params[:id], lock_version: params[:lock_version])
      @connection, @secret = result.values_at(:record, :secret)
      render :secret
    end
    def webhook
      @webhook = HrmIntegration::Application::Queries::FindWebhook.new.call(actor: current_user, id: params[:id])
    end
    def payload
      @payload = HrmIntegration::Application::Queries::ReadPayload.new.call(actor: current_user, id: params[:id])
    end
    def review
      record = HrmIntegration::Application::Commands::ReviewWebhook.new.call(actor: current_user, id: params[:id], decision: params[:decision], note: params[:note], lock_version: params[:lock_version])
      redirect_to "/integration/inbox/#{record.id}", notice: I18n.t("hrm_quality.messages.da_ghi_nhan_ket_qua_kiem_tra_su_kien")
    end
  end
end
