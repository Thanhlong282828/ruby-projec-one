class ShiftAssignmentsController < ApplicationController
  rescue_from ActiveRecord::RecordInvalid do |error|
    if action_name == "destroy"
      redirect_to shift_assignment_path(params[:id]), alert: error.record.errors.full_messages.to_sentence
    else
      @data=workspace.call(actor: current_user, id: params[:id], form: true)
      @data[:record]=error.record
      render :form, status: :unprocessable_content
    end
  end
  rescue_from HrmAttendance::Application::Queries::EmployeeShiftSchedule::InvalidPeriod do |error|
    render plain: error.message, status: :unprocessable_content
  end
  rescue_from ActionController::ParameterMissing do |error|
    render plain: error.message, status: :bad_request
  end
  def index
    @data=workspace.call(actor: current_user, page: params[:page])
  end
  def show
    @data=workspace.call(actor: current_user, id: params[:id])
  end
  def new = prepare_form
  def edit = prepare_form
  def create
    record=HrmAttendance::Application::Commands::CreateShiftAssignment.new.call(actor: current_user, attributes: record_params)
    redirect_to shift_assignment_path(record), notice: I18n.t("hrm_quality.messages.da_phan_ca")
  end
  def update
    record=HrmAttendance::Application::Commands::UpdateShiftAssignment.new.call(actor: current_user, id: params[:id], attributes: record_params)
    redirect_to shift_assignment_path(record), notice: I18n.t("hrm_quality.messages.da_cap_nhat_ngay_ket_thuc")
  end
  def destroy
    HrmAttendance::Application::Commands::DeleteShiftAssignment.new.call(actor: current_user, id: params[:id], lock_version: params[:lock_version])
    redirect_to shift_assignments_path, notice: I18n.t("hrm_quality.messages.da_xoa_phan_ca_tuong_lai")
  end
  def schedule
    @data=HrmAttendance::Application::Queries::EmployeeShiftSchedule.new.call(actor: current_user, employee_id: params[:employee_id], from: params[:from], to: params[:to])
  end
  private
  def workspace = HrmAttendance::Application::Queries::ShiftAssignmentWorkspace.new
  def record_params = HrmAttendance::Application::Requests::ShiftAssignmentRequest.read(params)
  def prepare_form
    @data=workspace.call(actor: current_user, id: params[:id], form: true)
    render :form
  end
end
