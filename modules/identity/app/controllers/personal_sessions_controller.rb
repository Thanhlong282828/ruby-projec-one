class PersonalSessionsController < ApplicationController
  def index
    @workspace = HrmIdentity::Application::Queries::PersonalSessions.new.call(actor: current_user, credential: authenticated_login, before: params[:before])
  end
  def destroy
    HrmIdentity::Application::Commands::RevokePersonalSession.new.call(actor: current_user, credential: authenticated_login, id: params[:id])
    redirect_to "/my/sessions", notice: I18n.t("hrm_quality.messages.da_dang_xuat_phien_da_chon")
  end
end
