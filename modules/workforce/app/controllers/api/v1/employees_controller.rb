module Api
  module V1
    class EmployeesController < BaseController
      before_action :set_employee, only: [:show, :update, :destroy]
      def index
        authorize Employee
        render json: { data: page(policy_scope(Employee).order(:id)).map(&:public_attributes) }
      end
      def show
        render json: { data: @employee.public_attributes }
      end
      def create
        employee = Employee.new(employee_params)
        authorize employee
        employee.save!
        render json: { data: employee.public_attributes }, status: :created
      end
      def update
        @employee.update!(employee_params)
        render json: { data: @employee.public_attributes }
      end
      def destroy
        if @employee.destroy
          head :no_content
        else
          render json: { error: "dependent_records", details: @employee.errors.full_messages }, status: :conflict
        end
      end
      private
      def set_employee
        @employee = policy_scope(Employee).find(params[:id])
        authorize @employee
      end
      def employee_params
        params.require(:employee).permit(:employee_code, :full_name, :email, :job_title, :hired_on, :status, :department_id, :salary_cents, :annual_leave_days, :lock_version)
      end
    end
  end
end
