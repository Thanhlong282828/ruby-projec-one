module Api
  module V1
    class LeaveRequestsController < BaseController
      def index
        authorize LeaveRequest
        render json: { data: page(policy_scope(LeaveRequest).order(id: :desc)) }
      end
      def show
        request = policy_scope(LeaveRequest).find(params[:id])
        authorize request
        render json: { data: request }
      end
      def create
        attributes = params.require(:leave_request).permit(:employee_id, :starts_on, :ends_on, :reason)
        employee = policy_scope(Employee).find(attributes.delete(:employee_id))
        authorize employee.leave_requests.new(attributes)
        request = TimeOff::Submit.call(employee: employee, attributes: attributes)
        render json: { data: request }, status: :created
      end
      def approve = review("approved")
      def reject = review("rejected")
      private
      def review(decision)
        request = policy_scope(LeaveRequest).find(params[:id])
        authorize request, decision == "approved" ? :approve? : :reject?
        TimeOff::Review.call(request: request, reviewer: current_user, decision: decision)
        render json: { data: request }
      end
    end
  end
end
