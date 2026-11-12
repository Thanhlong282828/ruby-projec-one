# Kiến trúc HRM

Kiến trúc ứng dụng đã có Provider + Application Command/Query + Domain Repository Interface + Infrastructure Active Record. Xem [mapping DJI Laravel](DJI_ARCHITECTURE_MAPPING.md) cho quyết định và giới hạn.

Mã nguồn hiện được đóng gói thành 12 local gem Rails Engines trong `modules/`. Mỗi domain sở hữu MVC, policy, service và test; platform chứa lớp nền và UI dùng chung. Xem [quy tắc và ranh giới module](MODULES.md).

Ruby on Rails 8.1 / Ruby 3.4 / MySQL 8.4. Modular monolith với microservice nhận sự kiện riêng. MVC giữ controller mỏng, nghiệp vụ đặt tại modules/<module>/lib/hrm_<module>/application và domain (app/services còn các facade tương thích), policy tách quyền truy cập. Chưa phải hệ thống microservices phân tán toàn bộ nghiệp vụ.

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
- TimeOff: Submit khóa employee; Review khóa employee rồi request để tránh vượt số dư do duyệt đồng thời. Không tự duyệt đơn. Ngày phép tính theo ngày lịch, cùng năm. Mặc định role manager có leave.review/leave.read_all trong company; quyền có thể đổi trong MySQL. Chưa giới hạn theo nhóm quản lý.
- Attendance: một ca/ngày theo giờ Việt Nam; check-in/out của chính nhân viên.
- Payroll: chụp lương cơ bản của nhân viên active; kỳ lương unique theo company + tháng; chốt một chiều. Không tích hợp chi trả, thuế, BHXH, prorate hay OT.
- Recruitment: quản lý ứng viên và giai đoạn.
- Hrm: observer, audit, event bus, transactional outbox; thư viện thuần Ruby `modules/time_off/lib/hrm/calendar.rb` tính ngày dùng lại trong domain.

## Tính năng kỹ thuật
| Yêu cầu | Triển khai |
|---|---|
| ORM / Active Record | Models, associations, scopes, enum, constraints |
| Migration | module migrations, db/structure.sql giữ MySQL triggers |
| Routing / REST | config/routes.rb; API version v1 |
| Validation | Model validation + MySQL indexes/check constraint |
| Middleware | Rack::Attack, Rails CSRF/cookies/request ID |
| Authentication | bcrypt, session rotation, API token SHA-256, TTL 8h, revoke |
| Authorization | Pundit policies + tenant scope, MySQL RBAC, user grant/deny và composite FK chống IDOR/liên kết chéo company |
| Queue / backend | Active Job / Sidekiq / Redis AOF |
| Scheduler | sidekiq-cron: outbox mỗi phút, email tổng hợp 08:00 VN |
| Event / Observer | ObservableRecord → Hrm::RecordObserver → ActiveSupport::Notifications |
| Cache | Redis, TTL và invalidation sau commit |
| Realtime | Action Cable qua Redis; cần realtime.read, stream theo company và recheck quyền trước transmit |
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
Mật khẩu được hash, không mã hóa hai chiều. Dữ liệu nhạy cảm được mã hóa hai chiều với khóa trong biến môi trường. API không trả bank_account/national_id/salary; chỉ người có employees.sensitive trong cùng company được xem lương và ngân hàng trên web. Log/audit không lưu giá trị nhạy cảm. Không có đăng ký công khai. Chỉ accounts.manage được sửa vai trò/quyền cho tài khoản khác cùng company; không cho tự sửa quyền chính mình.

Audit và outbox ghi trong cùng transaction với model. Scheduler phục hồi việc gửi outbox khi receiver mất kết nối. Delivery là at-least-once; receiver dedup ID, nhưng email và realtime có thể lặp nếu worker dừng giữa gửi và đánh dấu delivered. Sau 8 lần retry job thất bại, scheduler vẫn tạo lượt dispatch mới cho các sự kiện pending. Theo dõi outbox lâu chưa gửi và Sidekiq dead jobs. Outbox hiện xử lý tuần tự 100 sự kiện mỗi lượt, cần mở rộng partition/batching nếu tải lớn.

Local dùng HTTP và secrets tạo riêng trong .env. Production cần HTTPS reverse proxy, Redis private/ACL, SMTP thật, quản lý khóa/rotation, backup MySQL + khóa mã hóa, monitoring, policy lưu/xóa PII, kiểm tra tải. Các cấu hình development trong compose không được xem là production deployment.


## Company & RBAC MySQL (28/10/2026)

Một định danh đăng nhập có nhiều membership theo company; mỗi User profile vẫn thuộc đúng một company; `company_roles`, `permissions`, `role_permissions` và `user_permissions` lưu quyền thật trong MySQL. Vai trò tùy chỉnh không cần sửa enum. Web `/manage/company`, `/manage/roles`, `/manage/accounts`; REST `/api/v1/company`, `/api/v1/roles`, `/api/v1/accounts`. `User#allowed?` đọc DB, Policy kiểm permission và company; các scope, payroll, cache, email, audit/outbox và realtime đều giới hạn tenant. Hướng dẫn: [Company & permission](../HUONG_DAN_COMPANY_PERMISSION_MYSQL.txt) ở gốc project.

Multi-company: `/system/companies` là danh mục quản trị tổng (SystemGrant riêng), `/my/companies` chọn membership của một login identity, `/organization/branches` quản lý nhiều chi nhánh trong company hiện tại. Quyền business vẫn theo profile/role/overrides từng company; không flip user.company_id hoặc copy password. Chi nhánh dùng OrganizationUnit thật, chưa có ABAC giới hạn từng branch xuyên ERP. Đọc HUONG_DAN_NHIEU_CONG_TY_CHI_NHANH_LARAVEL_RUBY.txt ở gốc repo.
Schema chuẩn: db/structure.sql giữ MySQL trigger; local/CI dùng bin/prepare-mysql-tls, bin/migrate-docker và bin/test-docker. Không dùng app user để tạo trigger hoặc tự load test schema. Production phải cấu hình CA/migration role/secrets riêng; chưa deploy cloud thật.

### Executable engine boundaries and strict Payroll slice

`config/engine_boundaries.yml` + `bin/check-architecture` enforce the verified 12-engine dependency graph, repository provider ownership/completeness and Controller → Application entry points. Shared top-level models remain an explicit modular-monolith exception: Payroll reconciliation locks Workforce Employee and reads Attendance/Leave rows under company scope; this is not 12 separately isolated databases. The legacy TimeOff review exception and transport error rescues retain existing API behavior. Fixture-based negative gate tests reject controller container access, missing/cross-owned bindings and Payroll reaching Leave Infrastructure or undeclared IAM contracts.

The Payroll closing/read/reconciliation path is gradually typed with Sorbet, including its repository contracts/implementations and snapshot result shape; see QUALITY.md for the exact scope and dynamic boundaries. Provider bindings remain strings, preserving Rails reload behavior.
