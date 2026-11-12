class HrUpdatesChannel < ApplicationCable::Channel
  def subscribed
    return reject unless connection.session_authenticated? && current_user.allowed?("realtime.read")
    company_id = current_user.company_id
    stream_from "company_#{company_id}_hr_updates", coder: ActiveSupport::JSON do |message|
      # Recheck active account/company and current grants for existing subscriptions too.
      if connection.session_authenticated? && current_user.reload.company_id == company_id && current_user.allowed?("realtime.read")
        transmit(message) if Hrm::RealtimeAuthorization.allowed?(actor: current_user, message: message)
      else
        stop_all_streams
      end
    rescue ActiveRecord::RecordNotFound
      stop_all_streams
    end
  end
end
# Đoạn code này là một Action Cable Channel có phân quyền Realtime theo công ty (Multi-Tenant Authorization) trong Ruby on Rails.

# Nó nâng cao hơn hai đoạn ApplicationCable::Connection và ApplicationCable::Channel bạn gửi trước đó.

# Mục đích chính: Chỉ những nhân viên có quyền realtime.read mới được nhận thông báo HRM của công ty mình. Khi có thông báo mới, hệ thống kiểm tra lại quyền trước khi gửi tới trình duyệt.
