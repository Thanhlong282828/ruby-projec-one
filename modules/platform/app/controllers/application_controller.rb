class ApplicationController < ActionController::Base
  include Pundit::Authorization
  before_action :authenticate_user!
  before_action { Current.user = current_user }
  helper_method :current_user
  rescue_from Pundit::NotAuthorizedError do
    render plain: "Bạn không có quyền thực hiện thao tác này.", status: :forbidden
  end
  rescue_from ActiveRecord::RecordNotFound do
    render plain: "Không tìm thấy dữ liệu.", status: :not_found
  end
  rescue_from ActiveRecord::StaleObjectError do
    render plain: "Dữ liệu đã được cập nhật bởi người khác. Hãy tải lại trang.", status: :conflict
  end
  private
  def current_user
    @current_user ||= User.find_by(id: session[:user_id], active: true)
  end
  def authenticate_user!
    redirect_to new_session_path unless current_user
  end
  def page(scope)
    scope.limit(25).offset(([params[:page].to_i, 1].max - 1) * 25)
  end
end
