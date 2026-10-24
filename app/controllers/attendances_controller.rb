class AttendancesController < ApplicationController
  def index
    authorize Attendance
    @attendances = page(policy_scope(Attendance).includes(:employee).order(work_date: :desc))
  end
  def create
    employee = current_user.employee || raise(ActiveRecord::RecordNotFound)
    attendance = employee.attendances.new(work_date: Date.current, checked_in_at: Time.current)
    authorize attendance
    attendance.save!
    redirect_to attendances_path, notice: "Đã vào ca."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    redirect_to attendances_path, alert: "Bạn đã chấm công hôm nay."
  end
  def checkout
    attendance = policy_scope(Attendance).find(params[:id])
    authorize attendance
    attendance.with_lock do
      attendance.update!(checked_out_at: Time.current) unless attendance.checked_out_at
    end
    redirect_to attendances_path, notice: "Đã kết thúc ca."
  end
end
