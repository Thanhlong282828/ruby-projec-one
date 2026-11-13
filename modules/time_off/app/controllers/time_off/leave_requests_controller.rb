module TimeOff
  class LeaveRequestsController < ApplicationController
    def index
      @requests = HrmTimeOff::Application::Queries::ListLeaveRequests.new.call(actor: current_user, page: params[:page], status: params[:status])
    end
    def show
      authorize LeaveRequest, :index?
      @request = HrmTimeOff::Application::Queries::FindLeaveRequest.new.call(actor: current_user, id: params[:id])
      authorize @request, :show?
    end
    def new
      @request = LeaveRequest.new
      load_employees
    end
    def create
      attributes = HrmTimeOff::Application::Requests::LeaveRequestParameters.read(params)
      @request = HrmTimeOff::Application::Commands::SubmitLeave.new.call(actor: current_user, employee_id: attributes.delete(:employee_id), attributes: attributes)
      redirect_to leave_requests_path, notice: I18n.t("hrm_quality.messages.da_gui_don_nghi_phep")
    rescue ActiveRecord::RecordInvalid => error
      @request = error.record
      load_employees
      render :new, status: :unprocessable_content
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
      redirect_to leave_requests_path, notice: I18n.t("hrm_quality.messages.da_xu_ly_don")
    rescue Review::InvalidTransition => error
      redirect_to leave_requests_path, alert: error.message
    end
  end
end
