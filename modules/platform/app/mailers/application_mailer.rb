class ApplicationMailer < ActionMailer::Base # ApplicationMailer: Lớp Mailer cơ sở của ứng dụng.  |  <: Kế thừa trong Ruby, tương tự extends của PHP.  |  ActionMailer::Base: Framework Rails hỗ trợ tạo và gửi email.
  default from: "from@example.com" # B. Địa chỉ người gửi mặc định | from@example.com hiện là địa chỉ mẫu, chưa phải địa chỉ gửi email production thực tế. | Bạn có thể cấu hình bằng biến môi trường:  default from: ENV.fetch("MAIL_FROM_ADDRESS")   >  Lưu ý: default from chỉ thiết lập header người gửi, không tự cấu hình SMTP hoặc bảo đảm email được gửi thành công.
  layout "mailer" # C. Layout của Email  |  Chỉ định layout dùng chung cho các email.
end
# Đoạn code này trong Ruby on Rails là ApplicationMailer, lớp cha dùng chung để xây dựng chức năng gửi Email trong hệ thống HRM.

# Nó tương đương với việc tạo một BaseMailer trong Laravel.
