module Api
  module V1
    class IntegrationHubController < BaseController
      rescue_from HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload do
        render json: { error: "invalid_filter" }, status: :bad_request
      end
      def index
        data = HrmIntegration::Application::Queries::Workspace.new.call(actor: current_user, page: params[:page], status: params[:status])
        render json: { counts: data[:counts], page: data[:page], next_page: data[:next_page], connections: data[:connections].map(&:public_attributes), webhooks: data[:webhooks].map(&:public_attributes) }
      end
      def connection
        render json: HrmIntegration::Application::Queries::FindConnection.new.call(actor: current_user, id: params[:id]).public_attributes
      end
      def create
        result = HrmIntegration::Application::Commands::CreateConnection.new.call(actor: current_user, attributes: HrmIntegration::Application::Requests::ConnectionParameters.read(params))
        render json: result[:record].public_attributes.merge(signing_secret: result[:secret]), status: :created
      end
      def toggle
        render json: HrmIntegration::Application::Commands::ToggleConnection.new.call(actor: current_user, id: params[:id], active: params[:active], lock_version: params[:lock_version]).public_attributes
      end
      def rotate
        result = HrmIntegration::Application::Commands::RotateConnectionSecret.new.call(actor: current_user, id: params[:id], lock_version: params[:lock_version])
        render json: result[:record].public_attributes.merge(signing_secret: result[:secret])
      end
      def webhook
        render json: HrmIntegration::Application::Queries::FindWebhook.new.call(actor: current_user, id: params[:id]).public_attributes
      end
      def payload
        render json: HrmIntegration::Application::Queries::ReadPayload.new.call(actor: current_user, id: params[:id])
      end
      def review
        render json: HrmIntegration::Application::Commands::ReviewWebhook.new.call(actor: current_user, id: params[:id], decision: params[:decision], note: params[:note], lock_version: params[:lock_version]).public_attributes
      end
    end
  end
end
