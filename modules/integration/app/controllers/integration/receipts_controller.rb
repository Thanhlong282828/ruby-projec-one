module Integration
  class ReceiptsController < ActionController::API
    include SensitiveResponseHeaders
    rescue_from HrmIntegration::Domain::Services::WebhookSignature::Unauthorized do
      render json: { error: "unauthorized_webhook" }, status: :unauthorized
    end
    rescue_from HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload do
      render json: { error: "invalid_webhook" }, status: :bad_request
    end
    rescue_from HrmIntegration::Domain::Services::WebhookSignature::Conflict do
      render json: { error: "event_id_conflict" }, status: :conflict
    end
    def create
      # Do not access params: Rails JSON parsing would consume an unbounded raw body.
      unless request.env["hrm.integration.webhook_json"] == true
        render json: { error: "json_required" }, status: :unsupported_media_type
        return
      end
      body = request.body.read(HrmIntegration::Domain::Services::WebhookSignature::MAX_BYTES + 1)
      if body.bytesize > HrmIntegration::Domain::Services::WebhookSignature::MAX_BYTES
        render json: { error: "body_too_large" }, status: :content_too_large
        return
      end
      result = HrmIntegration::Application::Commands::ReceiveWebhook.new.call(
        public_id: request.path_parameters.fetch(:public_id),
        timestamp: request.headers["X-Webhook-Timestamp"], event_id: request.headers["X-Webhook-Id"],
        signature: request.headers["X-Webhook-Signature"], body: body)
      render json: result, status: :accepted
    end
  end
end
