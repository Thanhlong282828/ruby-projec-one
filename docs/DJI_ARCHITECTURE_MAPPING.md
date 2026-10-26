# DJI Laravel → Ruby HRM: mapping kiến trúc

## Nguồn đã đọc (read-only)

Desktop/laraveldji/admin:
- Modules/Attendance/app/Providers/AttendanceServiceProvider.php: repository bindings và schedule.
- Modules/Attendance/app/Providers/RouteServiceProvider.php và EventServiceProvider.php.
- Modules/Attendance/app/Domain/Repositories/AttendanceWriteRepositoryInterface.php.
- Modules/Attendance/app/Infrastructure/Persistence/EloquentAttendanceWriteRepository.php.
- Modules/Attendance/app/Domain/Services/AttendanceCaptureService.php.
- Modules/Attendance/app/Application/Commands/CheckIn/{CheckInCommand,CheckInHandler}.php.
- Modules/Attendance/app/Application/Queries/GetAttendanceDashboard/GetAttendanceDashboardQuery.php.
- Modules/Attendance/app/Presentation/Http/Requests/CaptureAttendanceRequest.php.
- Modules/Employee/app/Providers/EmployeeServiceProvider.php.

Đây là tham chiếu kiến trúc; không sao chép .env, credentials, database hoặc sửa dự án Laravel.

## Mapping

| DJI Laravel | Ruby HRM |
|---|---|
| ModuleServiceProvider::register + app->bind | Providers::<Module>ServiceProvider + Hrm::Container.bind |
| module.json / composer.json | Gemfile + module gemspec + Rails Engine |
| Domain/Repositories/*Interface | lib/hrm_<module>/domain/repositories/*_interface.rb |
| Infrastructure/Persistence/Eloquent*Repository | lib/hrm_<module>/infrastructure/persistence/active_record_*_repository.rb |
| Application/Commands + Handler | lib/hrm_<module>/application/commands/*: class nhận keyword arguments và call |
| Application/Queries + Handler | lib/hrm_<module>/application/queries/* |
| Domain/Services | lib/hrm_<module>/domain/services/* |
| Presentation/Http/Controllers | app/controllers |
| Presentation/Http/Requests | application/requests: allowlist require/permit; validation tiếp tục ở Model và Domain |
| Domain/Models dùng Eloquent | app/models dùng Active Record |
| Blade | app/views/*.html.erb |
| EventServiceProvider | Audit EventServiceProvider, đăng ký lại an toàn khi reload |
| configureSchedules | config/schedule.yml trong module; Sidekiq Cron nạp khi worker khởi động |

## Quyết định thiết kế

- Giữ chuẩn Rails MVC và bảng/model hiện hữu để không phải đổi schema và URL. Các layer Ruby nằm trong lib theo namespace, được Zeitwerk nạp; không lồng app/application/hrm_attendance/application gây khó đọc.
- Mỗi module có ServiceProvider thực sự được Engine gọi trong to_prepare. Có 16 binding repository: đọc/ghi của Workforce, Identity, Attendance, TimeOff, Payroll, Recruitment, Audit; thêm Outbox của Platform và Read của Dashboard. Dashboard không có write repository giả.
- Container nhỏ dùng string constant names, không cache repository instance; resolve kiểm tra implementation kế thừa interface. Ruby interface là abstract base class với NotImplementedError, không phải interface kiểm tra kiểu lúc biên dịch như PHP.
- Constructor injection cho phép kiểm thử bằng fake repository. Controller web/API dùng chung Command/Query và request allowlist. Query giữ Pundit scope; Command tự kiểm tra actor/quyền.
- CQRS ở mức application code, cùng database MySQL. Query vẫn có thể trả Active Record records và mảng đã load cho MVC; chưa áp dụng CQRS với read database riêng hoặc domain entities độc lập khỏi ORM.
- Attendance Domain Service kiểm tra nhân viên active/probation, khóa employee trước khi chống check-in trùng. Check-out giữ ownership và khóa record.
- Duyệt phép khóa employee rồi request; thay đổi trạng thái, audit và outbox rollback cùng transaction nếu bước ghi sự kiện thất bại.
- Các facade TimeOff::Review, TimeOff::Submit và Payroll::BuildRun/FinalizeRun giữ tương thích code cũ; controller mới gọi use case trực tiếp. TimeOff::Submit là trusted internal compatibility entrypoint, không dùng làm HTTP API.
- Scheduled jobs và local CLI gọi các lớp tương ứng. Không tạo ba job DJI nếu Rails chưa có dữ liệu Work Profile, ca làm hoặc anomaly workflow tương ứng.

## Giới hạn nghiệp vụ

Rails hiện là HRM một tổ chức: một ca/ngày, nghỉ phép theo ngày lịch, bảng lương cơ bản. Chưa đưa company/branch isolation, Work Profile, ca xoay, overtime, device integration, anomaly detection, bảo hiểm/thuế và payroll readiness từ DJI sang. Việc bổ sung cần schema, quyền và kiểm thử nghiệp vụ riêng; không tạo stub trả thành công để tuyên bố có tính năng.

## Kiểm tra

ruby bin/check-routes
ruby bin/check-architecture
bin/test-docker
docker compose run --rm web bundle exec rails zeitwerk:check
docker compose run --rm web bundle exec ruby bin/brakeman --no-pager

Static gate kiểm tra các lời gọi query/write trực tiếp phổ biến trong controller/view. Đây không phải bằng chứng cách ly module tuyệt đối; regression tests, policy scopes và code review vẫn cần thiết.
