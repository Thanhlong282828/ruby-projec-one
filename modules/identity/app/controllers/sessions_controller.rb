class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create]
  def new; end
  def create
    user = HrmIdentity::Application::Queries::AuthenticateUser.new.call(email: params[:email], password: params[:password])
    if user
      reset_session
      session[:user_id] = user.id
      redirect_to root_path
    else
      flash.now[:alert] = "Email hoặc mật khẩu không đúng."
      render :new, status: :unprocessable_entity
    end
  end
  def destroy
    reset_session
    redirect_to new_session_path
  end
end
