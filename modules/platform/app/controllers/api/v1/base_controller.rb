module Api
  module V1
    class BaseController < ActionController::API #A. ActionController::API  |   Ví dụ Laravel tương đương về mục đích:class BaseController extends Controller{}
      include Pundit::Authorization # B. include Pundit::Authorization | Pundit là thư viện phân quyền trong Rails, tương tự Laravel Policy.  Ví dụ: authorize employee, :update?  | Rails gọi Policy phù hợp để quyết định người dùng có được sửa nhân viên hay không.   |  Lưu ý: include Pundit::Authorization chỉ cung cấp các phương thức phân quyền. Nó không tự động kiểm tra quyền cho tất cả API Action.
      before_action :authenticate_token! # C. before_action | before_action tương tự cơ chế Middleware hoặc các hook trước Controller Action trong Laravel.
      before_action { Current.user = current_user } # C. before_action  |  Hai callback chạy theo thứ tự: 1. authenticate_token!: Xác thực Bearer Token.  2. Current.user = current_user: Gán người dùng vào request context.
      rescue_from Pundit::NotAuthorizedError do
        render json: { error: "forbidden" }, status: :forbidden
      end
      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "not_found" }, status: :not_found
      end
      rescue_from ActiveRecord::RecordInvalid do |error|
        render json: { error: "validation_failed", details: error.record.errors.to_hash }, status: :unprocessable_entity
      end
      rescue_from ActionController::ParameterMissing do |error|
        render json: { error: "missing_parameter", details: error.param }, status: :bad_request
      end
      rescue_from ActiveRecord::StaleObjectError, ActiveRecord::RecordNotUnique do
        render json: { error: "conflict" }, status: :conflict
      end
      rescue_from TimeOff::Review::InvalidTransition do |error|
        render json: { error: error.message }, status: :conflict
      end
      #3. Phân tích Authentication
      private
      def current_user = @current_user
      def authenticate_token!
        raw = request.authorization.to_s.delete_prefix("Bearer ") # A. Lấy Bearer Token  |  Ví dụ client gửi: GET /api/v1/employees Authorization: Bearer abc123xyz  |  Kết quả: raw = "abc123xyz"
        @api_token = HrmIdentity::Application::Queries::AuthenticateToken.new.call(raw: raw) # B. Xác thực Token bằng Query Object  |  Đây là cách tổ chức theo Application Layer / Query Object.   |  Nhiệm vụ dự kiến của AuthenticateToken là kiểm tra token và trả về đối tượng token hợp lệ. |  Tuy nhiên, cần xem code bên trong để biết có kiểm tra token hết hạn, thu hồi hoặc hash token hay không.
        @current_user = @api_token&.user # C. Lấy User | Dấu &. trong Ruby gọi là Safe Navigation Operator.  |  Ví dụ: token = nil    user = token&.user  |  Kết quả user = nil, không phát sinh lỗi vì gọi .user trên nil.  |  Tương tự PHP 8: $user = $token?->user;
        render(json: { error: "unauthorized" }, status: :unauthorized) unless @current_user&.active? && @current_user.company.active? # D. Kiểm tra User và Company  | unless @current_user&.active? && @current_user.company.active? | API chỉ tiếp tục nếu: - Company của User đang hoạt động.  |  Nếu không thỏa mãn, trả về HTTP 401 Unauthorized.
      end
    end
  end
end
#Đoạn code này là Base API Controller của Ruby on Rails,
# dùng để quản lý những chức năng chung cho các API thuộc phiên bản v1.

# Nó tương đương với việc bạn xây dựng Api\BaseController trong Laravel,
#  kết hợp Bearer Token Authentication + Pundit Authorization + Exception Handling + Multi-Tenant Security.

# Client gửi API Request
# Authorization: Bearer TOKEN
          # v
# authenticate_token!
# Xác thực token, user và company
          # v
# Current.user = current_user
# Thiết lập ngữ cảnh người dùng cho request
          # v
# API Controller Action
# Xử lý nghiệp vụ, Pundit Policy, Database
          # v
# JSON Response
# 200 / 201 hoặc 401 / 403 / 404 / 409 / 422 / 400
