module Workforce
  class EmployeesController < ApplicationController
    before_action :set_employee, only: [ :show, :edit, :update, :destroy ]

    def index
      @employees = HrmWorkforce::Application::Queries::ListEmployees.new.call(actor: current_user, page: params[:page], search: params[:q])
    end
    def show; end
    def new
      @employee = Employee.new(company: current_user.company, hired_on: Date.current)
      authorize @employee
      load_form_options
    end
    def edit = load_form_options
    def create
      @employee = HrmWorkforce::Application::Commands::CreateEmployee.new.call(actor: current_user, attributes: employee_params)
      redirect_to @employee, notice: I18n.t("hrm_quality.messages.da_tao_nhan_vien")
    rescue ActiveRecord::RecordInvalid => error
      @employee = error.record
      load_form_options
      render :new, status: :unprocessable_content
    end
    def update
      HrmWorkforce::Application::Commands::UpdateEmployee.new.call(actor: current_user, record: @employee, attributes: employee_params)
      redirect_to @employee, notice: I18n.t("hrm_quality.messages.da_cap_nhat_ho_so")
    rescue ActiveRecord::RecordInvalid
      load_form_options
      render :edit, status: :unprocessable_content
    end
    def destroy
      if HrmWorkforce::Application::Commands::DeleteEmployee.new.call(actor: current_user, record: @employee)
        redirect_to employees_path, notice: I18n.t("hrm_quality.messages.da_xoa_nhan_vien")
      else
        redirect_to @employee, alert: @employee.errors.full_messages.to_sentence
      end
    end
    private
    def set_employee
      @employee = HrmWorkforce::Application::Queries::FindEmployee.new.call(actor: current_user, id: params[:id])
      authorize @employee
    end
    def load_form_options
      options = HrmWorkforce::Application::Queries::EmployeeFormOptions.new.call(actor: current_user)
      @departments, @users = options.values_at(:departments, :users)
    end
    def employee_params = HrmWorkforce::Application::Requests::EmployeeRequest.read(params)
  end
end
