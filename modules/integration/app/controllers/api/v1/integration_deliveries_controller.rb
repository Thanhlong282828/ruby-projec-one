module Api
  module V1
    class IntegrationDeliveriesController < BaseController
      rescue_from HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload, ActionController::ParameterMissing do
        render json: { error: "invalid_delivery" }, status: :bad_request
      end
      rescue_from HrmIntegration::Domain::Services::WebhookSignature::Conflict do
        render json: { error: "idempotency_conflict" }, status: :conflict
      end
      rescue_from HrmIntegration::Infrastructure::Http::OutboundTransport::Unavailable do
        render json: { error: "target_configuration_unavailable" }, status: :service_unavailable
      end
      def index
        data = HrmIntegration::Application::Queries::OutboundWorkspace.new.call(actor: current_user, page: params[:page], status: params[:status])
        render json: { records: data[:records].map(&:public_attributes), counts: data[:counts], page: data[:page], next_page: data[:next_page], targets: data[:targets] }
      end
      def show
        data = HrmIntegration::Application::Queries::FindDelivery.new.call(actor: current_user, id: params[:id])
        render json: { record: data[:record].public_attributes, attempts: data[:attempts] }
      end
      def payload
        data = HrmIntegration::Application::Queries::FindDelivery.new.call(actor: current_user, id: params[:id], payload: true)
        render json: { id: data[:record].id, body: data[:body] }
      end
      def create
        record = HrmIntegration::Application::Commands::QueueDelivery.new.call(actor: current_user, **HrmIntegration::Application::Requests::DeliveryParameters.read(params))
        render json: record.public_attributes, status: :accepted
      end
      def retry
        record = HrmIntegration::Application::Commands::RetryDelivery.new.call(actor: current_user, id: params[:id], lock_version: params[:lock_version])
        render json: record.public_attributes, status: :accepted
      end
    end
  end
end
