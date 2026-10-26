module Api
  module V1
    class LeaveRequestsController < BaseController
      def index
        records = HrmTimeOff::Application::Queries::ListLeaveRequests.new.call(actor: current_user, page: params[:page])
        render json: { data: records }
      end
      def show
        request = HrmTimeOff::Application::Queries::FindLeaveRequest.new.call(actor: current_user, id: params[:id])
        authorize request
        render json: { data: request }
      end
      def create
        attributes = HrmTimeOff::Application::Requests::LeaveRequestParameters.read(params)
        request = HrmTimeOff::Application::Commands::SubmitLeave.new.call(actor: current_user, employee_id: attributes.delete(:employee_id), attributes: attributes)
        render json: { data: request }, status: :created
      end
      def approve = review("approved")
      def reject = review("rejected")
      private
      def review(decision)
        request = HrmTimeOff::Application::Queries::FindLeaveRequest.new.call(actor: current_user, id: params[:id])
        HrmTimeOff::Application::Commands::ReviewLeave.new.call(request: request, reviewer: current_user, decision: decision)
        render json: { data: request }
      end
    end
  end
end
