module Api
  module V1
    class DepartmentsController < BaseController
      before_action :set_department, only: [:show, :update, :destroy]
      def index
        authorize Department
        render json: { data: page(policy_scope(Department).order(:id)) }
      end
      def show = render(json: { data: @department })
      def create
        department = Department.new(department_params)
        authorize department
        department.save!
        render json: { data: department }, status: :created
      end
      def update
        @department.update!(department_params)
        render json: { data: @department }
      end
      def destroy
        if @department.destroy
          head :no_content
        else
          render json: { error: "dependent_records" }, status: :conflict
        end
      end
      private
      def set_department
        @department = policy_scope(Department).find(params[:id])
        authorize @department
      end
      def department_params = params.require(:department).permit(:name, :code)
    end
  end
end
