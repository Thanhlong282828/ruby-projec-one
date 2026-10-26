module Api
  module V1
    class DepartmentsController < BaseController
      before_action :set_record, only: [:show, :update, :destroy]
      def index
        records = HrmWorkforce::Application::Queries::ListDepartments.new.call(actor: current_user, page: params[:page])
        render json: { data: records }
      end
      def show
        render json: { data: @record }
      end
      def create
        record = HrmWorkforce::Application::Commands::CreateDepartment.new.call(actor: current_user, attributes: record_params)
        render json: { data: record }, status: :created
      end
      def update
        HrmWorkforce::Application::Commands::UpdateDepartment.new.call(actor: current_user, record: @record, attributes: record_params)
        render json: { data: @record }
      end
      def destroy
        if HrmWorkforce::Application::Commands::DeleteDepartment.new.call(actor: current_user, record: @record)
          head :no_content
        else
          render json: { error: "dependent_records", details: @record.errors.full_messages }, status: :conflict
        end
      end
      private
      def set_record
        @record = HrmWorkforce::Application::Queries::FindDepartment.new.call(actor: current_user, id: params[:id])
        authorize @record
      end
      def record_params = HrmWorkforce::Application::Requests::DepartmentRequest.read(params)
    end
  end
end
