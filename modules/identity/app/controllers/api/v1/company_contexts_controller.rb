module Api
  module V1
    class CompanyContextsController < BaseController
      rescue_from HrmIdentity::Domain::Services::TenantInput::Invalid do
        render json: { error: "invalid_membership" }, status: :bad_request
      end
      def index
        render json: HrmIdentity::Application::Queries::CompanyMemberships.new.call(actor: current_user)
      end
      def create
        user = HrmIdentity::Application::Commands::SwitchCompany.new.call(actor: current_user, credential: @api_token, membership_id: params[:membership_id])
        render json: { membership_id: user.id, company_id: user.company_id, role: user.role }
      end
    end
  end
end
