class AttendancesController < ApplicationController
  def index
    @can_clock_in = current_user.allowed?("attendance.clock") && HrmWorkforce::Application::Queries::CurrentEmployee.new.call(actor: current_user).present?
    @attendances = HrmAttendance::Application::Queries::ListAttendances.new.call(actor: current_user, page: params[:page])
  end
  def show
    @data=HrmAttendance::Application::Queries::AttendanceDetail.new.call(actor: current_user, id: params[:id])
  end

  def create
    HrmAttendance::Application::Commands::CheckIn.new.call(actor: current_user)
    redirect_to attendances_path, notice: I18n.t("hrm_quality.messages.da_vao_ca")
  rescue HrmAttendance::Domain::Services::AttendanceCaptureService::InvalidState => error
    redirect_to attendances_path, alert: error.message
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    redirect_to attendances_path, alert: I18n.t("hrm_quality.messages.ban_da_cham_cong_hom_nay")
  end

  def checkout
    HrmAttendance::Application::Commands::CheckOut.new.call(actor: current_user, id: params[:id])
    redirect_to attendances_path, notice: I18n.t("hrm_quality.messages.da_ket_thuc_ca")
  end
end
