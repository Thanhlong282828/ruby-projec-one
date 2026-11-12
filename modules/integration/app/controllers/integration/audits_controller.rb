module Integration
  class AuditsController < ApplicationController
    helper IntegrationAuditHelper
    rescue_from HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload do
      render plain: "Bộ lọc nhật ký không hợp lệ. Khoảng thời gian tối đa 93 ngày.", status: :bad_request
    end
    def index
      @workspace = HrmIntegration::Application::Queries::AuditWorkspace.new.call(actor: current_user,
        **HrmIntegration::Application::Requests::AuditParameters.read(params))
    end
  end
end
