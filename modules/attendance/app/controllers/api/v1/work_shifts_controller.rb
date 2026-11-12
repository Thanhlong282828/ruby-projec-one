module Api
  module V1
    class WorkShiftsController < BaseController
      rescue_from ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey do
        render json: { error: "shift_in_use" }, status: :conflict
      end
      def index
        data = workspace.call(actor: current_user, page: params[:page])
        render json: { records: data.fetch(:records).map(&:public_attributes) }
      end
      def show
        render json: workspace.call(actor: current_user, id: params[:id]).fetch(:record).public_attributes
      end
      def create
        record = HrmAttendance::Application::Commands::CreateWorkShift.new.call(actor: current_user, attributes: record_params)
        render json: record.public_attributes, status: :created
      end
      def update
        record = HrmAttendance::Application::Commands::UpdateWorkShift.new.call(actor: current_user, id: params[:id], attributes: record_params)
        render json: record.public_attributes
      end
      def destroy
        HrmAttendance::Application::Commands::DeleteWorkShift.new.call(actor: current_user, id: params[:id], lock_version: params[:lock_version])
        head :no_content
      end
      def preview
        render json: HrmAttendance::Application::Queries::PreviewWorkShift.new.call(actor: current_user, id: params[:id], attendance_id: params.require(:attendance_id))
      end
      private
      def workspace = HrmAttendance::Application::Queries::WorkShiftWorkspace.new
      def record_params = HrmAttendance::Application::Requests::WorkShiftRequest.read(params)
    end
  end
end
