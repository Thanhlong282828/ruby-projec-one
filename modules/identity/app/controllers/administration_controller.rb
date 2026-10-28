class AdministrationController < ApplicationController
  rescue_from HrmIdentity::Domain::InvalidAdministration, ActiveRecord::RecordInvalid do |error|
    @administration_error = error.message
    prepare(@area, id: @account_id)
    render @area == :company ? :company : (@area == :accounts ? :account : :roles), status: :unprocessable_entity
  end
  def company = prepare(:company)
  def accounts = prepare(:accounts)
  def account = prepare(:accounts, id: params[:id])
  def roles = prepare(:roles)
  def save_company
    apply(:company)
    redirect_to administration_company_path, notice: "Đã cập nhật company."
  end
  def save_account
    apply(:accounts, id: params[:id])
    redirect_to administration_accounts_path, notice: "Đã lưu vai trò và quyền tài khoản trong MySQL."
  end
  def save_role
    apply(:roles, id: params[:id])
    redirect_to administration_roles_path, notice: "Đã cập nhật quyền vai trò trong MySQL."
  end
  private
  def prepare(area, id: nil)
    @data = HrmIdentity::Application::Queries::Administration.new.call(actor: current_user, area: area, id: id)
  end
  def apply(area, id: nil)
    @area, @account_id = area, id
    HrmIdentity::Application::Commands::ManageCompanyAccess.new.call(actor: current_user, area: area, id: id, attributes: HrmIdentity::Application::Requests::AdministrationRequest.read(params, area: area))
  end
end
