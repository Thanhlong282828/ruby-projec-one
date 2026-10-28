# Company + RBAC MySQL — kiểm chứng 28/10/2026

- Thực hiện trực tiếp trên project Ruby hiện tại và database hrm_development, không tạo checkout/database clone.
- Migration MySQL thêm companies, permissions, company_roles, role_permissions, user_permissions; backfill company cho dữ liệu cũ và FK tổng hợp chống liên kết chéo company, gồm users(company_id,role) -> company_roles(company_id,key).
- Đã sao lưu development trước migration. Fingerprints các cột gốc và số dòng của 11 bảng được đối chiếu trước/sau migration: không đổi. 7 tài khoản hiện có được gắn company XINVIEC/vai trò, không đổi mật khẩu.
- MySQL development: 1 company, 29 permission, 4 role defaults, 67 role grants; vai trò tùy chỉnh và account grant/deny tạo/sửa được qua web/API.
- Rails/Minitest trên hrm_test: **75 tests, 335 assertions, 0 failures/errors/skips**. Gồm quyền động/deny, custom roles, company scopes, chống IDOR, composite FK thực tế, payroll snapshots, cache permission digest, mail summary scope, API token cũ sau thu quyền, actor stale, protected admin và role case/whitespace.
- Action Cable tenant tests đạt; stream riêng từng company, permission recheck và JSON coder.
- Zeitwerk đạt; explicit route gate đạt 10 routing files; architecture gate đạt 17 controllers và views.
- Brakeman quét 17 controllers, 18 models, 31 templates: **0 errors, 0 security warnings**; không thêm ignore để bỏ qua privileged role input.
- Docker web/worker build thành công; đối chiếu 225 Ruby files trong image khớp checkout, eager load và 17 bindings đạt; đọc được MySQL/grants thật, không chứa config/master.key. App/worker restart, /up HTTP 200.
- Đăng nhập thật trên development: dashboard, /manage/company, /manage/roles, /manage/accounts đều HTTP 200, khoảng 41–192 ms trong lượt smoke đã đo. Không tạo thêm dữ liệu nghiệp vụ cho smoke này.
- Hướng dẫn mới: HUONG_DAN_COMPANY_PERMISSION_MYSQL.txt. Bốn TXT cũ đã sửa ngay các ô Ruby từng ghi thiếu company/single-org; phần Node vẫn mô tả đúng project Node chưa được thay đổi.
- Phạm vi: một account thuộc một company; admin chỉ trong company. Chưa có switch nhiều membership/branch scope cho một account và không tuyên bố ngang toàn bộ nghiệp vụ DJI.

Các mục bên dưới là lịch sử kiểm tra các lần trước, không phải số lượng test/bindings hiện tại (hiện 17 bindings).

---

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

## Sau nâng cấp kiến trúc tham chiếu Laravel DJI — 26/10/2026

- 9 module có ServiceProvider; container đăng ký 16 repository contracts bằng tên lớp, hỗ trợ Rails reload và constructor injection.
- Rails/Minitest: 45 tests, 202 assertions, 0 failures, 0 errors, 0 skips.
- Kiểm thử gồm phân quyền trực tiếp tại use case, chống truy cập bản ghi người khác, chặn chấm công nhân viên không hoạt động, rollback duyệt đơn khi outbox lỗi, và dữ liệu danh sách được nạp trước View.
- Kiểm tra route tường minh: đạt 10 files; kiểm tra kiến trúc: đạt 15 controllers và các views.
- Zeitwerk eager loading đạt; reload giữ đủ 16 bindings hợp lệ.
- Brakeman: 15 controllers, 13 models, 27 templates; 0 errors, 0 security warnings.
- Build Docker web/worker thành công. Image chạy độc lập nạp đủ lớp và 16 bindings; không chứa config/master.key.
- Web health HTTP 200, worker khởi động thành công sau cập nhật mã.
- Không thay đổi migration/schema, không reset dữ liệu development, không chỉnh sửa hoặc sao chép dữ liệu/secrets Laravel DJI.
- Đây là nâng cấp kiến trúc nghiệp vụ Rails hiện có; không phải chuyển toàn bộ tính năng đa công ty, ca làm, tăng ca hoặc thuế từ DJI.
- Hướng dẫn người mới: HUONG_DAN_LARAVEL_SANG_RAILS.txt; đối chiếu nguồn tham khảo: docs/DJI_ARCHITECTURE_MAPPING.md.

Các kết quả trên là kiểm tra local của lần nâng cấp này; không thay thế nghiệm thu nghiệp vụ, kiểm tra tải hoặc pentest production.
