class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :new, :create ]
  def new; end
  def create
    user = HrmIdentity::Application::Queries::AuthenticateUser.new.call(email: params[:email], password: params[:password])
    if user
      HrmIdentity::Application::Commands::CloseWebSession.new.call(raw: session[:login_token])
      raw = HrmIdentity::Application::Commands::OpenWebSession.new.call(actor: user)
      reset_session
      session[:login_token] = raw
      redirect_to root_path
    else
      flash.now[:alert] = I18n.t("hrm_quality.messages.email_hoac_mat_khau_khong_dung")
      render :new, status: :unprocessable_content
    end
  end
  def destroy
    HrmIdentity::Application::Commands::CloseWebSession.new.call(raw: session[:login_token])
    reset_session
    redirect_to new_session_path
  end
end
