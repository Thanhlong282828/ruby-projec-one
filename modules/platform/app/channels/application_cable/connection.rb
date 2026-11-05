module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user
    def connect
      self.current_user = HrmIdentity::Application::Queries::FindActiveUser.new.call(id: request.session[:user_id]) || reject_unauthorized_connection
    end
  end
end
# Đoạn code này trong Ruby on Rails đang thực hiện Authentication cho kết nối WebSocket của Action Cable.

# Nói đơn giản: Khi trình duyệt muốn kết nối WebSocket,
# Rails sẽ kiểm tra Session để xác định người dùng.
# Nếu tài khoản không tồn tại hoặc không còn hoạt động, Rails từ chối kết nối.

# Đây là phần bổ sung cho ApplicationCable::Channel mà bạn vừa hỏi.
