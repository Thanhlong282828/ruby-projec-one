# hrm_payroll

Thư viện Rails Engine nội bộ, phiên bản 0.1.0.

**Sở hữu:** PayRun, Payslip, BuildRun/FinalizeRun và MVC bảng lương.

**Liên kết runtime:** Workforce, Identity, Audit, Platform.

- `app/models`: Model / Active Record / validation (nếu module có dữ liệu riêng).
- `app/controllers`: Controller web và/hoặc API.
- `app/views`: View ERB của module (nếu có giao diện).
- `app/policies`, `app/services`, `app/jobs`, `app/mailers`: các lớp đúng trách nhiệm của module.
- `config/routes/payroll.rb`: fragment routing được host ghép bằng `draw :payroll`.
- `lib`: engine entrypoint và thư viện Ruby / Rake tasks.
- `db/migrate`: migration mới do module sở hữu.
- `test`: kiểm thử module; kiểm thử luồng xuyên module ở host `test/integration`.

Không phải module nào cũng cần đủ tất cả thư mục. Dashboard không có bảng dữ liệu riêng; không tạo Model giả để đủ cấu trúc.

Engine dùng chung schema, constants và host route helpers để tương thích database/API hiện tại. Đây là các thư viện liên kết trong cùng ứng dụng, chưa phải gem độc lập chạy ngoài hệ thống hoặc microservice riêng. Không đổi tên bảng và không chạy lại migration khởi tạo.

## Các layer nghiệp vụ

- lib/hrm_payroll/providers: ServiceProvider nối Interface → implementation.
- lib/hrm_payroll/application/queries: luồng đọc.
- lib/hrm_payroll/application/commands: luồng ghi (khi module có nghiệp vụ ghi).
- lib/hrm_payroll/application/requests: giới hạn trường HTTP được nhận (khi cần).
- lib/hrm_payroll/domain/repositories: repository interfaces.
- lib/hrm_payroll/domain/services: quy tắc nghiệp vụ tách riêng (khi cần).
- lib/hrm_payroll/infrastructure/persistence: implementation Active Record.

Model Active Record và MVC vẫn ở app/. Engine gọi ServiceProvider khi khởi động/reload. Đọc hướng dẫn HUONG_DAN_LARAVEL_SANG_RAILS.txt ở gốc dự án và docs/DJI_ARCHITECTURE_MAPPING.md trước khi thêm use case.
