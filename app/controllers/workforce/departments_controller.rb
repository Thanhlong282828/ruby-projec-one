module Workforce
  class DepartmentsController < ApplicationController
    before_action :set_department, only: [:edit, :update, :destroy]
    def index
      authorize Department
      @departments = page(policy_scope(Department).order(:name))
    end
    def new
      @department = Department.new
      authorize @department
    end
    def create
      @department = Department.new(department_params)
      authorize @department
      @department.save ? redirect_to(departments_path, notice: "Đã thêm phòng ban.") : render(:new, status: :unprocessable_entity)
    end
    def edit; end
    def update
      @department.update(department_params) ? redirect_to(departments_path, notice: "Đã cập nhật.") : render(:edit, status: :unprocessable_entity)
    end
    def destroy
      @department.destroy
      redirect_to departments_path, alert: @department.errors.full_messages.to_sentence.presence
    end
    private
    def set_department
      @department = policy_scope(Department).find(params[:id])
      authorize @department
    end
    def department_params = params.require(:department).permit(:name, :code)
  end
end
