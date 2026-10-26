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
    @current_user ||= HrmIdentity::Application::Queries::FindActiveUser.new.call(id: session[:user_id])
  end
  def authenticate_user!
    redirect_to new_session_path unless current_user
  end
end
