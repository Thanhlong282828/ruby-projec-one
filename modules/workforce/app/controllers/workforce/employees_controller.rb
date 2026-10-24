module Workforce
  class EmployeesController < ApplicationController
    before_action :set_employee, only: [:show, :edit, :update, :destroy]
    def index
      authorize Employee
      @employees = policy_scope(Employee).includes(:department).order(:employee_code)
      @employees = @employees.where("full_name LIKE ? OR employee_code LIKE ?", "%#{Employee.sanitize_sql_like(params[:q])}%", "%#{Employee.sanitize_sql_like(params[:q])}%") if params[:q].present?
      @employees = page(@employees)
    end
    def show; end
    def new
      @employee = Employee.new(hired_on: Date.current)
      authorize @employee
    end
    def create
      @employee = Employee.new(employee_params)
      authorize @employee
      if @employee.save
        redirect_to @employee, notice: "Đã tạo nhân viên."
      else
        render :new, status: :unprocessable_entity
      end
    end
    def edit; end
    def update
      if @employee.update(employee_params)
        redirect_to @employee, notice: "Đã cập nhật hồ sơ."
      else
        render :edit, status: :unprocessable_entity
      end
    end
    def destroy
      if @employee.destroy
        redirect_to employees_path, notice: "Đã xóa nhân viên."
      else
        redirect_to @employee, alert: @employee.errors.full_messages.to_sentence
      end
    end
    private
    def set_employee
      @employee = policy_scope(Employee).find(params[:id])
      authorize @employee
    end
    def employee_params
      params.require(:employee).permit(:department_id, :user_id, :employee_code, :full_name, :email, :job_title, :hired_on, :status, :salary_cents, :annual_leave_days, :bank_account, :national_id, :lock_version)
    end
  end
end
