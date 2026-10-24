module TimeOff
  class LeaveRequestsController < ApplicationController
    def index
      authorize LeaveRequest
      @requests = page(policy_scope(LeaveRequest).includes(:employee).order(created_at: :desc))
    end
    def new
      @request = LeaveRequest.new
      @employees = policy_scope(Employee)
    end
    def create
      employee = policy_scope(Employee).find(params.require(:leave_request)[:employee_id])
      @request = employee.leave_requests.new(request_params)
      authorize @request
      @request = Submit.call(employee: employee, attributes: request_params)
      redirect_to leave_requests_path, notice: "Đã gửi đơn nghỉ phép."
    rescue ActiveRecord::RecordInvalid => error
      @request = error.record
      @employees = policy_scope(Employee)
      render :new, status: :unprocessable_entity
    end
    def approve = review("approved")
    def reject = review("rejected")
    private
    def request_params = params.require(:leave_request).permit(:starts_on, :ends_on, :reason)
    def review(decision)
      request = policy_scope(LeaveRequest).find(params[:id])
      authorize request, decision == "approved" ? :approve? : :reject?
      Review.call(request: request, reviewer: current_user, decision: decision)
      redirect_to leave_requests_path, notice: "Đã xử lý đơn."
    rescue Review::InvalidTransition => error
      redirect_to leave_requests_path, alert: error.message
    end
  end
end
