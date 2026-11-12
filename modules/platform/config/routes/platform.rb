# Health check and WebSocket endpoint
get "/up", to: "rails/health#show", as: :rails_health_check # get "/up" — Health Check
mount ActionCable.server => "/cable"
# 1. get "/up" — Health Check
#       get "/up",
#           to: "rails/health#show",
#           as: :rails_health_check
# Thành phần                        	Ý nghĩa
# get                               	HTTP GET
# "/up"	                           Đường dẫn URL
# "rails/health#show"	      Action show của HealthController do Rails cung cấp
# as: :rails_health_check	      Đặt tên route để tạo URL helper

# Ví dụ khi truy cập:
#         GET http://localhost:3000/up
# Nếu Rails khởi tạo và endpoint hoạt động bình thường, thường trả về HTTP 200 OK.
# Nếu ứng dụng không sẵn sàng, có thể trả về lỗi hoặc không kết nối được.
# Lưu ý: Health Check mặc định không có nghĩa là MySQL, Redis, Queue, ActionCable đều hoạt động. Muốn kiểm tra những thành phần đó phải bổ sung cơ chế kiểm tra riêng.
# Laravel tương đương
# Laravel cũng có Health Route, thường được cấu hình qua bootstrap/app.php:
#             ->withRouting(
#                 web: __DIR__.'/../routes/web.php',
#                 commands: __DIR__.'/../routes/console.php',
#                 health: '/up',
#             )

# 2. mount ActionCable.server => "/cable" — Realtime
#         mount ActionCable.server => "/cable"
# Đây là dòng quan trọng liên quan đến kiến trúc Realtime HRM bạn đang học.
# Phân tích:
#       - ActionCable: Framework Realtime của Rails.
#       - .server: Lấy ActionCable Server.
#       - mount: Gắn một ứng dụng Rack vào hệ thống routing.
#       - "/cable": Đường dẫn mà WebSocket Client kết nối.
# Ví dụ Frontend kết nối:
#          import { createConsumer } from "@rails/actioncable";
#          const consumer = createConsumer(
#            "ws://localhost:3000/cable"
#          );
# Khi kết nối thành công, Client có thể subscribe vào Channel:
#         consumer.subscriptions.create(
#           "HrUpdatesChannel",
#           {
#             received(data) {
#               console.log(data);
#             }
#           }
#         );
# Tuy nhiên, kết nối thành công không có nghĩa Client được phép nhận tất cả sự kiện. Server vẫn phải xác thực người dùng và kiểm soát quyền subscribe.

# 3. Liên kết với toàn bộ kiến trúc Outbox của bạn
#           SalaryService / LeaveService
#           Phát sinh sự kiện nghiệp vụ
#                       v
#           ActiveRecordOutboxRepository
#           append! → Lưu OutboxEvent vào Database
#                       v
#           OutboxDispatchJob
#           pending → deliver → yield
#                       v
#           ActionCable.server.broadcast
#           Phát sự kiện đến stream tương ứng
#                       v
#           HrUpdatesChannel
#           Quản lý subscription vào stream HRM
#                       v
#           WebSocket Client qua /cable
#           Frontend nhận cập nhật Realtime
# /cable là endpoint kết nối WebSocket, không phải một REST API thông thường.

# 4. So sánh với Laravel
# Ruby on Rails                          	Laravel
# GET /up	                          Health Route /up
# ActionCable	                    Laravel Reverb + Broadcasting
# mount ActionCable.server    	  Cấu hình WebSocket server của Reverb
# /cable	                         Endpoint WebSocket, tương tự vai trò /app/{key} của Reverb
# HrUpdatesChannel	                Laravel Broadcast Channel
# ActionCable.server.broadcast	    Laravel Broadcasting Event

# Một khác biệt: Rails có thể phục vụ ActionCable qua chính ứng dụng Rails, còn Laravel Reverb là WebSocket server riêng.
