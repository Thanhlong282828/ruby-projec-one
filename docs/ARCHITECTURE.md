# Kiến trúc HRM

Ruby on Rails 8.1 / Ruby 3.4 / MySQL 8.4. Modular monolith với microservice nhận sự kiện riêng. MVC giữ controller mỏng, nghiệp vụ đặt tại app/services, policy tách quyền truy cập. Chưa phải hệ thống microservices phân tán toàn bộ nghiệp vụ.

```text
Browser (ERB/CSS/JS) ─┐
REST client ─────────┼─ Puma → Middleware → Authentication → Pundit → Controller
                    │                                      ↓
                    │                    Workforce / TimeOff / Payroll / Recruitment
                    │                                      ↓
                    │                         Active Record → MySQL
                    │                             Audit + Outbox (transaction)
                    └─ Action Cable ← Redis ← Sidekiq ← Scheduler
                                               ├─ SMTP / Mailpit
                                               └─ HMAC HTTP → Event Sink → SQLite dedup
```

## Module
- Workforce: Employee, Department, liên kết tài khoản, trạng thái nhân viên, tìm kiếm.
- TimeOff: Submit khóa employee; Review khóa employee rồi request để tránh vượt số dư do duyệt đồng thời. Không tự duyệt đơn. Ngày phép tính theo ngày lịch, cùng năm. Manager hiện được duyệt trên toàn tổ chức; chưa giới hạn theo nhóm quản lý.
- Attendance: một ca/ngày theo giờ Việt Nam; check-in/out của chính nhân viên.
- Payroll: chụp lương cơ bản của nhân viên active; kỳ lương unique theo tháng; chốt một chiều. Không tích hợp chi trả, thuế, BHXH, prorate hay OT.
- Recruitment: quản lý ứng viên và giai đoạn.
- Hrm: observer, audit, event bus, transactional outbox; thư viện thuần Ruby `lib/hrm/calendar.rb` tính ngày dùng lại trong domain.

## Tính năng kỹ thuật
| Yêu cầu | Triển khai |
|---|---|
| ORM / Active Record | Models, associations, scopes, enum, constraints |
| Migration | db/migrate, schema.rb do Rails sinh |
| Routing / REST | config/routes.rb; API version v1 |
| Validation | Model validation + MySQL indexes/check constraint |
| Middleware | Rack::Attack, Rails CSRF/cookies/request ID |
| Authentication | bcrypt, session rotation, API token SHA-256, TTL 8h, revoke |
| Authorization | Pundit policies + scope, IDOR protection |
| Queue / backend | Active Job / Sidekiq / Redis AOF |
| Scheduler | sidekiq-cron: outbox mỗi phút, email tổng hợp 08:00 VN |
| Event / Observer | ObservableRecord → Hrm::RecordObserver → ActiveSupport::Notifications |
| Cache | Redis, TTL và invalidation sau commit |
| Realtime | Action Cable qua Redis; chỉ staff subscribe |
| Mail | Action Mailer; SMTP, xem local bằng Mailpit |
| Testing | Minitest model/service/request/job + CI |
| CLI / package | Rake tasks / Bundler + Gemfile.lock |
| Template / web server | ERB / Puma |
| Docker | app, worker, MySQL, Redis, Mailpit, event_sink |
| Microservice | Event sink độc lập, xác minh HMAC, idempotent theo event ID |
| Encryption | Active Record Encryption cho bank_account/national_id |
| Clean code | module namespaces, service objects, policy objects |
| Bổ sung | optimistic locking, audit trail, pagination, health check, API docs |

## Bảo mật và độ tin cậy
Mật khẩu được hash, không mã hóa hai chiều. Dữ liệu nhạy cảm được mã hóa hai chiều với khóa trong biến môi trường. API không trả bank_account/national_id/salary; chỉ web staff được xem lương và ngân hàng. Log/audit không lưu giá trị nhạy cảm. Không có đăng ký công khai hay API tự sửa vai trò.

Audit và outbox ghi trong cùng transaction với model. Scheduler phục hồi việc gửi outbox khi receiver mất kết nối. Delivery là at-least-once; receiver dedup ID, nhưng email và realtime có thể lặp nếu worker dừng giữa gửi và đánh dấu delivered. Sau 8 lần retry job thất bại, scheduler vẫn tạo lượt dispatch mới cho các sự kiện pending. Theo dõi outbox lâu chưa gửi và Sidekiq dead jobs. Outbox hiện xử lý tuần tự 100 sự kiện mỗi lượt, cần mở rộng partition/batching nếu tải lớn.

Local dùng HTTP và secrets tạo riêng trong .env. Production cần HTTPS reverse proxy, Redis private/ACL, SMTP thật, quản lý khóa/rotation, backup MySQL + khóa mã hóa, monitoring, policy lưu/xóa PII, kiểm tra tải. Các cấu hình development trong compose không được xem là production deployment.
