module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end

# Đoạn code này trong Ruby on Rails đang khai báo một Base Channel cho Action Cable,
#  dùng làm lớp cha cho các Channel xử lý giao tiếp Realtime qua WebSocket.

# Nó tương tự cách Laravel sử dụng Broadcasting + Laravel Reverb,
#  nhưng không hoàn toàn giống nhau về kiến trúc.
