# hrm_dashboard

Thư viện Rails Engine nội bộ, phiên bản 0.1.0.

**Sở hữu:** Controller/View tổng quan, số liệu từ các module nghiệp vụ.

**Liên kết runtime:** Workforce, Attendance, TimeOff, Payroll, Recruitment, Onboarding, Integration; Identity/Platform cung cấp actor/quyền và nền dùng chung.

- `app/models`: Model / Active Record / validation (nếu module có dữ liệu riêng).
- `app/controllers`: Controller web và/hoặc API.
- `app/views`: View ERB của module (nếu có giao diện).
- `app/policies`, `app/services`, `app/jobs`, `app/mailers`: các lớp đúng trách nhiệm của module.
- `config/routes/dashboard.rb`: fragment routing được host ghép bằng `draw :dashboard`.
- `lib`: engine entrypoint và thư viện Ruby / Rake tasks.
- `db/migrate`: migration mới do module sở hữu.
- `test`: kiểm thử module; kiểm thử luồng xuyên module ở host `test/integration`.

Không phải module nào cũng cần đủ tất cả thư mục. Dashboard không có bảng dữ liệu riêng; không tạo Model giả để đủ cấu trúc.

Engine dùng chung schema, constants và host route helpers để tương thích database/API hiện tại. Đây là các thư viện liên kết trong cùng ứng dụng, chưa phải gem độc lập chạy ngoài hệ thống hoặc microservice riêng. Không đổi tên bảng và không chạy lại migration khởi tạo.

## Các layer nghiệp vụ

- lib/hrm_dashboard/providers: ServiceProvider nối Interface → implementation.
- lib/hrm_dashboard/application/queries: luồng đọc.
- lib/hrm_dashboard/application/commands: luồng ghi (khi module có nghiệp vụ ghi).
- lib/hrm_dashboard/application/requests: giới hạn trường HTTP được nhận (khi cần).
- lib/hrm_dashboard/domain/repositories: repository interfaces.
- lib/hrm_dashboard/domain/services: quy tắc nghiệp vụ tách riêng (khi cần).
- lib/hrm_dashboard/infrastructure/persistence: implementation Active Record.

Model Active Record và MVC vẫn ở app/. Engine gọi ServiceProvider khi khởi động/reload. Đọc hướng dẫn HUONG_DAN_LARAVEL_SANG_RAILS.txt ở gốc dự án và docs/DJI_ARCHITECTURE_MAPPING.md trước khi thêm use case.

## ERP workspace (13/11/2026)

8 KPI có link đến dữ liệu nguồn, 3 widget và board onboarding theo 8 trạng thái thật. Chỉ số Payroll gắn tháng chọn; các KPI khác ghi rõ phạm vi/trạng thái. Đọc trực tiếp qua contract module sở hữu, không cache30s hoặc SQL xuyên module. Ẩn cả giá trị/link nếu thiếu quyền. Sidebar và bảng nghiệp vụ dùng chung ErpNavigationHelper với9nhóm có route đang chạy.

Bấm card/widget/cột/dòng chỉ GET. Duyệt phép/chốt lương/checklist ở màn hình nguồn qua Command có policy/transaction hiện có. Company từ session/profile đã xác thực, không từ query parameter. Board preview100hồ sơ mới nhất; danh sách theo trạng thái phân trang25. Không coi dashboard là snapshot giao dịch toàn ERP.

Xem [bản đồ menu và nguồn](../../docs/ERP_NAVIGATION.md) và [kết quả kiểm chứng](../../docs/VERIFICATION.md). Không thêm KPI hoặc menu giả cho miền ERP chưa có.
