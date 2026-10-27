# hrm_audit

Thư viện Rails Engine nội bộ, phiên bản 0.1.0.

**Sở hữu:** AuditLog, RecordObserver, event subscription và MVC nhật ký.

**Liên kết runtime:** Identity, Platform; các domain phát sinh audit.

- `app/models`: Model / Active Record / validation (nếu module có dữ liệu riêng).
- `app/controllers`: Controller web và/hoặc API.
- `app/views`: View ERB của module (nếu có giao diện).
- `app/policies`, `app/services`, `app/jobs`, `app/mailers`: các lớp đúng trách nhiệm của module.
- `config/routes/audit.rb`: fragment routing được host ghép bằng `draw :audit`.
- `lib`: engine entrypoint và thư viện Ruby / Rake tasks.
- `db/migrate`: migration mới do module sở hữu.
- `test`: kiểm thử module; kiểm thử luồng xuyên module ở host `test/integration`.

Không phải module nào cũng cần đủ tất cả thư mục. Dashboard không có bảng dữ liệu riêng; không tạo Model giả để đủ cấu trúc.

Engine dùng chung schema, constants và host route helpers để tương thích database/API hiện tại. Đây là các thư viện liên kết trong cùng ứng dụng, chưa phải gem độc lập chạy ngoài hệ thống hoặc microservice riêng. Không đổi tên bảng và không chạy lại migration khởi tạo.

## Các layer nghiệp vụ

- lib/hrm_audit/providers: ServiceProvider nối Interface → implementation.
- lib/hrm_audit/application/queries: luồng đọc.
- lib/hrm_audit/application/commands: luồng ghi (khi module có nghiệp vụ ghi).
- lib/hrm_audit/application/requests: giới hạn trường HTTP được nhận (khi cần).
- lib/hrm_audit/domain/repositories: repository interfaces.
- lib/hrm_audit/domain/services: quy tắc nghiệp vụ tách riêng (khi cần).
- lib/hrm_audit/infrastructure/persistence: implementation Active Record.

Model Active Record và MVC vẫn ở app/. Engine gọi ServiceProvider khi khởi động/reload. Đọc hướng dẫn HUONG_DAN_LARAVEL_SANG_RAILS.txt ở gốc dự án và docs/DJI_ARCHITECTURE_MAPPING.md trước khi thêm use case.
