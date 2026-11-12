module Api
  module V1
    class AttendanceReportsController < BaseController
      def show
        render json: HrmAttendance::Application::Queries::PeriodReport.new.call(
          actor: current_user, from: params[:from], to: params[:to], page: params[:page])
      rescue HrmAttendance::Application::Queries::PeriodReport::InvalidPeriod => error
        render json: { error: "invalid_period", message: error.message }, status: :unprocessable_content
      end
    end
  end
end
