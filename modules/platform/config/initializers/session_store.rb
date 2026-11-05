Rails.application.config.session_store :cookie_store,
  key: "_xinviec_hrm", httponly: true, same_site: :lax,
  secure: Rails.env.production?, expire_after: 8.hours
# Đoạn code Ruby on Rails này đang cấu hình Session bằng Cookie, dùng để duy trì trạng thái đăng nhập của người dùng.

# Nó tương tự cấu hình config/session.php trong Laravel, nhưng có một điểm khác biệt quan trọng: Rails cookie_store lưu dữ liệu Session trong Cookie được mã hóa ở trình duyệt, còn Laravel có thể lưu Session ở file, database hoặc Redis.
