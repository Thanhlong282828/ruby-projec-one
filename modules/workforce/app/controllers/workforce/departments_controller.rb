module Workforce
  class DepartmentsController < ApplicationController
    before_action :set_department, only: [:edit, :update, :destroy]
    def index
      @departments = HrmWorkforce::Application::Queries::ListDepartments.new.call(actor: current_user, page: params[:page])
    end
    def new
      @department = Department.new(company: current_user.company)
      authorize @department
    end
    def create
      HrmWorkforce::Application::Commands::CreateDepartment.new.call(actor: current_user, attributes: department_params)
      redirect_to departments_path, notice: "Đã thêm phòng ban."
    rescue ActiveRecord::RecordInvalid => error
      @department = error.record
      render :new, status: :unprocessable_entity
    end
    def edit; end
    def update
      HrmWorkforce::Application::Commands::UpdateDepartment.new.call(actor: current_user, record: @department, attributes: department_params)
      redirect_to departments_path, notice: "Đã cập nhật."
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end
    def destroy
      HrmWorkforce::Application::Commands::DeleteDepartment.new.call(actor: current_user, record: @department)
      redirect_to departments_path, alert: @department.errors.full_messages.to_sentence.presence
    end
    private
    def set_department
      @department = HrmWorkforce::Application::Queries::FindDepartment.new.call(actor: current_user, id: params[:id])
      authorize @department
    end
    def department_params = HrmWorkforce::Application::Requests::DepartmentRequest.read(params)
  end
end
