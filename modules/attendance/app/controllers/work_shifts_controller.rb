class WorkShiftsController < ApplicationController
  rescue_from ActiveRecord::RecordInvalid do |error|
    @record = error.record
    render :form, status: :unprocessable_content
  end
  rescue_from ActionController::ParameterMissing do |error|
    render plain: error.message, status: :bad_request
  end
  rescue_from ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey do
    redirect_to work_shifts_path, alert: I18n.t("hrm_quality.messages.khong_the_xoa_ca_dang_co_phan_cong")
  end
  def index
    @records = workspace.call(actor: current_user, page: params[:page]).fetch(:records)
  end
  def show
    data = workspace.call(actor: current_user, id: params[:id])
    @record, @attendance_options = data.values_at(:record, :attendance_options)
  end
  def new = prepare_form
  def edit = prepare_form
  def create
    record = HrmAttendance::Application::Commands::CreateWorkShift.new.call(actor: current_user, attributes: record_params)
    redirect_to work_shift_path(record), notice: I18n.t("hrm_quality.messages.da_tao_ca_lam_viec")
  end
  def update
    record = HrmAttendance::Application::Commands::UpdateWorkShift.new.call(actor: current_user, id: params[:id], attributes: record_params)
    redirect_to work_shift_path(record), notice: I18n.t("hrm_quality.messages.da_cap_nhat_ca_lam_viec")
  end
  def destroy
    HrmAttendance::Application::Commands::DeleteWorkShift.new.call(actor: current_user, id: params[:id], lock_version: params[:lock_version])
    redirect_to work_shifts_path, notice: I18n.t("hrm_quality.messages.da_xoa_ca_lam_viec")
  end
  def preview
    @preview = HrmAttendance::Application::Queries::PreviewWorkShift.new.call(actor: current_user, id: params[:id], attendance_id: params.require(:attendance_id))
  end
  private
  def workspace = HrmAttendance::Application::Queries::WorkShiftWorkspace.new
  def record_params = HrmAttendance::Application::Requests::WorkShiftRequest.read(params)
  def prepare_form
    @record = workspace.call(actor: current_user, id: params[:id], form: true).fetch(:record)
    render :form
  end
end
