module Api
  module V1
    class SessionsController < BaseController
      skip_before_action :authenticate_token!, only: :create
      def create
        user = HrmIdentity::Application::Queries::AuthenticateUser.new.call(email: params[:email], password: params[:password])
        if user
          render json: { token: HrmIdentity::Application::Commands::IssueToken.new.call(actor: user), token_type: "Bearer", expires_in: 28800 }, status: :created
        else
          render json: { error: "invalid_credentials" }, status: :unauthorized
        end
      end
      def destroy
        HrmIdentity::Application::Commands::RevokeToken.new.call(actor: current_user, token: @api_token)
        head :no_content
      end
    end
  end
end
