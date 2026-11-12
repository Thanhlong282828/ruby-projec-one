module Api
  module V1
    class IntegrationAuditsController < BaseController
      rescue_from HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload do
        render json: { error: "invalid_audit_filter" }, status: :bad_request
      end
      def index
        render json: HrmIntegration::Application::Queries::AuditWorkspace.new.call(actor: current_user,
          **HrmIntegration::Application::Requests::AuditParameters.read(params))
      end
    end
  end
end
