module Api
  module V1
    class EmployeesController < BaseController
      before_action :set_record, only: [:show, :update, :destroy]
      def index
        records = HrmWorkforce::Application::Queries::ListEmployees.new.call(actor: current_user, page: params[:page], api: true)
        render json: { data: records.map(&:public_attributes) }
      end
      def show
        render json: { data: @record.public_attributes }
      end
      def create
        record = HrmWorkforce::Application::Commands::CreateEmployee.new.call(actor: current_user, attributes: record_params)
        render json: { data: record.public_attributes }, status: :created
      end
      def update
        HrmWorkforce::Application::Commands::UpdateEmployee.new.call(actor: current_user, record: @record, attributes: record_params)
        render json: { data: @record.public_attributes }
      end
      def destroy
        if HrmWorkforce::Application::Commands::DeleteEmployee.new.call(actor: current_user, record: @record)
          head :no_content
        else
          render json: { error: "dependent_records", details: @record.errors.full_messages }, status: :conflict
        end
      end
      private
      def set_record
        @record = HrmWorkforce::Application::Queries::FindEmployee.new.call(actor: current_user, id: params[:id])
        authorize @record
      end
      def record_params = HrmWorkforce::Application::Requests::EmployeeRequest.read(params, api: true)
    end
  end
end
