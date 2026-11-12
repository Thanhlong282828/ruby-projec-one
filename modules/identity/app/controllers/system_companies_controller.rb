class SystemCompaniesController < ApplicationController
  rescue_from HrmIdentity::Domain::Services::TenantInput::Invalid, ActionController::ParameterMissing do
    render plain: "Dữ liệu công ty hoặc membership không hợp lệ.", status: :bad_request
  end
  rescue_from ActiveRecord::RecordInvalid do |error|
    render plain: error.record.errors.full_messages.join("; "), status: :unprocessable_content
  end
  rescue_from ActiveRecord::RecordNotUnique do
    render plain: "Mã công ty hoặc membership đã tồn tại.", status: :conflict
  end
  def index
    @workspace = HrmIdentity::Application::Queries::SystemCompanies.new.call(actor: current_user, before: params[:before])
  end
  def show
    @workspace = HrmIdentity::Application::Queries::SystemCompany.new.call(actor: current_user, id: params[:id])
  end
  def create
    attrs = params.expect(company: [ :code, :name ]).to_h.symbolize_keys
    record = HrmIdentity::Application::Commands::CreateSystemCompany.new.call(actor: current_user, attributes: attrs)
    redirect_to "/system/companies/#{record.id}", notice: I18n.t("hrm_quality.messages.da_tao_cong_ty_va_membership_quan_tri_rieng_trong_mysql")
  end
  def update
    attrs = params.expect(company: [ :name, :active ]).to_h.symbolize_keys
    HrmIdentity::Application::Commands::UpdateSystemCompany.new.call(actor: current_user, id: params[:id], attributes: attrs, lock_version: params[:lock_version])
    redirect_to "/system/companies/#{params[:id]}", notice: I18n.t("hrm_quality.messages.da_cap_nhat_cong_ty")
  end
  def membership
    HrmIdentity::Application::Commands::AssignCompanyMembership.new.call(actor: current_user, company_id: params[:id], principal_id: params[:principal_id], role: params[:role])
    redirect_to "/system/companies/#{params[:id]}", notice: I18n.t("hrm_quality.messages.da_cap_membership_khong_tao_mat_khau_hay_sao_chep_quyen")
  end
end
