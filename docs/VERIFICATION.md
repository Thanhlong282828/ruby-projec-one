# Kết quả kiểm tra local — 25/10/2026 (giờ Việt Nam)

- Rails/Minitest trên MySQL: 24 tests, 82 assertions, 0 failures, 0 errors.
- Event sink: 3 tests đạt — HMAC, schema validation, delivery idempotency.
- Zeitwerk: eager loading đạt.
- Brakeman: 0 errors, 0 security warnings.
- Bundler Audit: không phát hiện lỗ hổng trong lockfile theo ruby-advisory-db cập nhật ngày 23/10/2026.
- Browser thật: đăng nhập admin, dashboard tiếng Việt, bố cục màn hình hẹp, Action Cable xác nhận subscription.
- Worker thật: Sidekiq xử lý outbox, email duyệt đơn và tổng hợp; Mailpit nhận 3 email demo.
- Event receiver thật: 14 events nhận, 14 events delivered, 0 pending tại thời điểm kiểm tra.
- Scheduler: đăng ký outbox + daily_hr_summary; xác nhận tác vụ outbox được scheduler tự enqueue và xử lý.

Ảnh: [dashboard](dashboard.jpg). Script chạy luồng demo: `script/smoke.rb` (chỉ development). Các số liệu demo có thể tăng khi chỉnh sửa dữ liệu hoặc chạy lại script.

Các kiểm thử không thay thế kiểm tra tải, pentest, quy trình nghiệm thu nghiệp vụ và kiểm thử triển khai production. Giao diện kiểm tra tự động qua request tests; thao tác trình duyệt kiểm tra trực tiếp ở local. CI đã được cấu hình, chưa có lượt chạy CI trên GitHub trong phiên này.

## Sau tái cấu trúc Module + MVC

- Toàn bộ nghiệp vụ và lớp nền đã chuyển vào 9 local gem Rails Engines.
- Bộ kiểm thử Rails sau chuyển: 26 tests, 87 assertions, 0 failures, 0 errors; gồm test của các module và hành trình xuyên module.
- Zeitwerk eager loading, web/API route helpers và CLI tasks được kiểm tra lại.
- Database baseline được giữ nguyên, không tạo lại schema hoặc xóa dữ liệu.
- Brakeman sau chuyển: quét đủ 15 controllers, 13 models, 27 templates; 0 warnings/errors.
- HTTP kiểm tra login và CSS từ engine platform: đạt, giữ tông vàng.
- Worker khởi động và xử lý outbox từ lịch khai báo của module.
