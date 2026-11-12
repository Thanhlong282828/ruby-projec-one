class AttendanceReportsController < ApplicationController
  def show
    @report = HrmAttendance::Application::Queries::PeriodReport.new.call(
      actor: current_user, from: params[:from], to: params[:to], page: params[:page])
  rescue HrmAttendance::Application::Queries::PeriodReport::InvalidPeriod => error
    render plain: error.message, status: :unprocessable_content
  end
end
