module TimeOff
  class LeaveRequestsController < ApplicationController
    def index
      @requests = HrmTimeOff::Application::Queries::ListLeaveRequests.new.call(actor: current_user, page: params[:page])
    end
    def new
      @request = LeaveRequest.new
      load_employees
    end
    def create
      attributes = HrmTimeOff::Application::Requests::LeaveRequestParameters.read(params)
      @request = HrmTimeOff::Application::Commands::SubmitLeave.new.call(actor: current_user, employee_id: attributes.delete(:employee_id), attributes: attributes)
      redirect_to leave_requests_path, notice: "Đã gửi đơn nghỉ phép."
    rescue ActiveRecord::RecordInvalid => error
      @request = error.record
      load_employees
      render :new, status: :unprocessable_entity
    end
    def approve = review("approved")
    def reject = review("rejected")
    private
    def load_employees
      @employees = HrmTimeOff::Application::Queries::EmployeeOptions.new.call(actor: current_user)
    end
    def review(decision)
      request = HrmTimeOff::Application::Queries::FindLeaveRequest.new.call(actor: current_user, id: params[:id])
      HrmTimeOff::Application::Commands::ReviewLeave.new.call(request: request, reviewer: current_user, decision: decision)
      redirect_to leave_requests_path, notice: "Đã xử lý đơn."
    rescue Review::InvalidTransition => error
      redirect_to leave_requests_path, alert: error.message
    end
  end
end
