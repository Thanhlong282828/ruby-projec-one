class ApplicationController < ActionController::Base # ActionController::Base cung cấp các chức năng dành cho Web Controller, chẳng hạn render HTML, Session, Cookie, CSRF protection và các helper.
  include SensitiveResponseHeaders
  include Pundit::Authorization # Tích hợp Pundit để kiểm tra quyền truy cập, tương tự Laravel Policy.
  before_action :authenticate_user! # Tích hợp Pundit để kiểm tra quyền truy cập, tương tự Laravel Policy. |  Trước khi chạy Action, Rails thực hiện theo thứ tự: 1. authenticate_user!: Kiểm tra người dùng đã đăng nhập. 2. Current.user = current_user: Đưa User vào ngữ cảnh request.
  before_action { Current.user = current_user } # Tích hợp Pundit để kiểm tra quyền truy cập, tương tự Laravel Policy. | 2. Current.user = current_user: Đưa User vào ngữ cảnh request.
  helper_method :current_user # Cho phép sử dụng current_user trực tiếp trong View ERB. | Ví dụ: <p>Xin chào, <%= current_user.full_name %></p>
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
    @current_user ||= authenticated_login&.user
  end
  def authenticated_login
    @authenticated_login ||= HrmIdentity::Application::Queries::AuthenticateWebSession.new.call(raw: session[:login_token])
  end
  def authenticate_user!
    redirect_to new_session_path unless current_user
  end
end
# Đoạn code này là ApplicationController của Ruby on Rails,
# đóng vai trò Controller cha cho các trang Web HRM sử dụng Session để đăng nhập.

# Khác với Api::V1::BaseController bạn gửi trước đó sử dụng Bearer Token,
#  Controller này sử dụng Session Authentication + Pundit Authorization + Exception Handling.
#
# 2. Luồng xác thực bằng Session
# Browser gửi HTTP Request
# Cookie chứa Rails Session
# v
# authenticate_user!
# Gọi current_user để xác định người đăng nhập
# v
# AuthenticateWebSession Query
# Tra login_sessions từ hash của session[:login_token], kiểm hạn và User
# v
# Có User
# Tiếp tục xử lý trang
# v
# Không có User
# Redirect tới trang đăng nhập
