module Api
  module V1
    class BaseController < ActionController::API
      include Pundit::Authorization
      before_action :authenticate_token!
      before_action { Current.user = current_user }
      rescue_from Pundit::NotAuthorizedError do
        render json: { error: "forbidden" }, status: :forbidden
      end
      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "not_found" }, status: :not_found
      end
      rescue_from ActiveRecord::RecordInvalid do |error|
        render json: { error: "validation_failed", details: error.record.errors.to_hash }, status: :unprocessable_entity
      end
      rescue_from ActionController::ParameterMissing do |error|
        render json: { error: "missing_parameter", details: error.param }, status: :bad_request
      end
      rescue_from ActiveRecord::StaleObjectError, ActiveRecord::RecordNotUnique do
        render json: { error: "conflict" }, status: :conflict
      end
      rescue_from TimeOff::Review::InvalidTransition do |error|
        render json: { error: error.message }, status: :conflict
      end
      private
      def current_user = @current_user
      def authenticate_token!
        raw = request.authorization.to_s.delete_prefix("Bearer ")
        @api_token = HrmIdentity::Application::Queries::AuthenticateToken.new.call(raw: raw)
        @current_user = @api_token&.user
        render(json: { error: "unauthorized" }, status: :unauthorized) unless @current_user&.active? && @current_user.company.active?
      end
    end
  end
end
