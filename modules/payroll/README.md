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

## Immutable payroll CSV snapshots

Web `/payroll/exports`, Bearer API `/api/v1/payroll/exports`: finalized source payroll only, 1..2000 rows and <=1MiB UTF-8 CSV. Server-selected payslips/employee codes, fixed VND integer units consistent with current UI (legacy *_cents columns are not divided by 100), formula-safe employee cells, encrypted MySQL artifact, UUID/period/checksum/size/count/amount integrity checks. One immutable v1 per company/pay run. Separate read/create/download permissions plus payroll.read, atomic access/Audit/Outbox before serving bytes, metadata-only JSON and tenant scopes.

This is a reconciliation artifact prerequisite, not DJI accounting journal/provider export parity. A manual Integration descriptor bridge now exists (payroll.exports.notify), with source FK/worker integrity/grants and scoped audit/realtime. It does not upload CSV. No automatic artifact transfer, maker-checker, provider mapping, amendment/reversal or statutory filing. See root `HUONG_DAN_XUAT_BANG_LUONG_LARAVEL_RUBY.txt`.

## Snapshot and reconciliation (12/11/2026)

New payslips capture employee code/name with salary while source employee rows are locked. Normal updates/deletes of the immutable payslip are rejected; finalized runs reject updates. Explicit privileged SQL can bypass model callbacks and is outside these write APIs. CSV creation uses the captured code, never the current employee profile. Existing encrypted artifacts remain independently immutable and verified.

Migration 20261112000009 adds nullable identity columns and reconciliation JSON without inventing historical identity. Legacy finalized runs without those identity snapshots cannot create a new export; previously created artifacts still download. There are no development payroll rows to backfill in this local installation.

The closing transaction locks current payslips, employees and source attendance/leave, captures counts/totals, and commits reconciliation, status, audit and outbox together. Base salary is not automatically prorated/deducted by attendance or leave. Open shifts and pending leave are recorded warnings, not new automatic closing prohibitions. Source reconciliation details require attendance.read_all and leave.read_all in addition to payroll.read. Payroll.read remains a company-wide payroll permission, not a personal-payslip-only permission.

Read repositories re-resolve the actual company-scoped PayRun and permission rather than trusting mutable attributes on a caller-supplied record. Finalize permission is rechecked after waiting for the run lock. Two-company workflow, export/download access, stale-transaction leave balance, simultaneous finalize and rollback tests cover these paths.
