class AdministrationController < ApplicationController
  rescue_from HrmIdentity::Domain::InvalidAdministration, ActiveRecord::RecordInvalid do |error|
    @administration_error = error.message
    prepare(@area, id: @account_id)
    render @area == :company ? :company : (@area == :accounts ? :account : :roles), status: :unprocessable_content
  end
  def company = prepare(:company)
  def accounts = prepare(:accounts)
  def account = prepare(:accounts, id: params[:id])
  def roles = prepare(:roles)
  def save_company
    apply(:company)
    redirect_to administration_company_path, notice: I18n.t("hrm_quality.messages.da_cap_nhat_company")
  end
  def save_account
    apply(:accounts, id: params[:id])
    redirect_to administration_accounts_path, notice: I18n.t("hrm_quality.messages.da_luu_vai_tro_va_quyen_tai_khoan_trong_mysql")
  end
  def save_role
    apply(:roles, id: params[:id])
    redirect_to administration_roles_path, notice: I18n.t("hrm_quality.messages.da_cap_nhat_quyen_vai_tro_trong_mysql")
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
