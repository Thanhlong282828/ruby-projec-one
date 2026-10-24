module Api
  module V1
    class SessionsController < BaseController
      skip_before_action :authenticate_token!, only: :create
      def create
        user = User.find_by(email: params[:email].to_s.strip.downcase, active: true)
        if user&.authenticate(params[:password].to_s)
          render json: { token: ApiToken.issue!(user), token_type: "Bearer", expires_in: 28800 }, status: :created
        else
          render json: { error: "invalid_credentials" }, status: :unauthorized
        end
      end
      def destroy
        @api_token.destroy!
        head :no_content
      end
    end
  end
end
