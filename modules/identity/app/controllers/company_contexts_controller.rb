class CompanyContextsController < ApplicationController
  rescue_from HrmIdentity::Domain::Services::TenantInput::Invalid do
    render plain: "Membership không hợp lệ.", status: :bad_request
  end
  def index
    @memberships = HrmIdentity::Application::Queries::CompanyMemberships.new.call(actor: current_user)
  end
  def create
    HrmIdentity::Application::Commands::SwitchCompany.new.call(actor: current_user, credential: authenticated_login, membership_id: params[:membership_id])
    redirect_to root_path, notice: I18n.t("hrm_quality.messages.da_chuyen_cong_ty_vai_tro_va_du_lieu_theo_membership_cua_cong_ty_da_chon")
  end
end
