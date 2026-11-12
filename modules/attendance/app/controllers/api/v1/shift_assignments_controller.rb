module Api
  module V1
    class ShiftAssignmentsController < BaseController
      rescue_from HrmAttendance::Application::Queries::EmployeeShiftSchedule::InvalidPeriod do |error|
        render json: { error: "invalid_period", message: error.message }, status: :unprocessable_content
      end
      def index
        render json: workspace.call(actor: current_user, page: params[:page])
      end
      def show
        render json: workspace.call(actor: current_user, id: params[:id]).fetch(:row)
      end
      def create
        record=HrmAttendance::Application::Commands::CreateShiftAssignment.new.call(actor: current_user, attributes: record_params)
        render json: record.public_attributes, status: :created
      end
      def update
        record=HrmAttendance::Application::Commands::UpdateShiftAssignment.new.call(actor: current_user, id: params[:id], attributes: record_params)
        render json: record.public_attributes
      end
      def destroy
        HrmAttendance::Application::Commands::DeleteShiftAssignment.new.call(actor: current_user, id: params[:id], lock_version: params[:lock_version])
        head :no_content
      end
      def schedule
        render json: HrmAttendance::Application::Queries::EmployeeShiftSchedule.new.call(actor: current_user, employee_id: params[:employee_id], from: params[:from], to: params[:to])
      end
      private
      def workspace = HrmAttendance::Application::Queries::ShiftAssignmentWorkspace.new
      def record_params = HrmAttendance::Application::Requests::ShiftAssignmentRequest.read(params)
    end
  end
end
