module Api
  module V1
    class OnboardingCasesController < BaseController
      def index
        workspace = HrmOnboarding::Application::Queries::Workspace.new.call(actor: current_user)
        render json: { counts: workspace[:counts], data: workspace[:cases].map(&:public_attributes) }
      end
      def show
        render json: HrmOnboarding::Application::Queries::FindCase.new.call(actor: current_user, id: params[:id]).public_attributes
      end
      def create
        record = HrmOnboarding::Application::Commands::CreateCase.new.call(actor: current_user, attributes: HrmOnboarding::Application::Requests::CaseParameters.read(params))
        render json: record.public_attributes, status: :created
      end
      def transition
        render json: HrmOnboarding::Application::Commands::TransitionCase.new.call(actor: current_user, id: params[:id], status: params[:status], lock_version: params[:lock_version]).public_attributes
      end
      def complete
        render json: HrmOnboarding::Application::Commands::CompleteChecklist.new.call(actor: current_user, id: params[:id], code: params[:code], lock_version: params[:lock_version]).public_attributes
      end
    end
  end
end
