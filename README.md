# XinViec HRM — Ruby on Rails

Dự án HRM MVC, tổ chức nghiệp vụ theo module. Rails 8.1 + Ruby 3.4 + MySQL 8.4; giao diện tiếng Việt; REST API; Sidekiq/Redis; Docker; dịch vụ nhận sự kiện độc lập.

## Khởi động
Yêu cầu Docker Desktop đang chạy. Không cần cài Ruby mới trên máy nếu dùng Docker, nhưng script bootstrap chạy được với Ruby hệ thống 2.6+.

```sh
cd ~/Desktop/xinviec/ruby
ruby bin/setup-docker
```

- Ứng dụng: http://localhost:3100
- Mailpit: http://localhost:8026
- Admin: `admin@hrm.local`; mật khẩu xem `SEED_ADMIN_PASSWORD` trong `.env`.
- Demo: `member1@hrm.local` đến `member6@hrm.local`, cùng mật khẩu seed; member3 là HR.
- `.env` tự sinh ngẫu nhiên, không commit. Giữ lại các khóa mã hóa nếu muốn đọc dữ liệu đã mã hóa.

```sh
docker compose logs -f web worker
docker compose stop
docker compose up -d
```
Dữ liệu nằm trong Docker volumes. Không dùng `down -v` nếu cần giữ dữ liệu.

## Kiểm thử
Tạo database test và cấp quyền riêng một lần:
```sh
docker compose exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS hrm_test; GRANT ALL ON hrm_test.* TO hrm;"'
bin/test-docker
docker compose run --rm web bundle exec rails zeitwerk:check
docker compose run --rm web bundle exec ruby bin/brakeman --no-pager
```
Database test tách khỏi development. Có CI chạy test, kiểm tra autoload và security scan.

## Tài khoản và CLI
```sh
docker compose run --rm -e EMAIL=new@example.test -e PASSWORD='your-strong-password' -e ROLE=employee web bundle exec rails hrm:create_user
docker compose run --rm -e EMAIL=new@example.test web bundle exec rails hrm:disable_user
docker compose run --rm web bundle exec rails hrm:dispatch_events
docker compose run --rm web bundle exec rails hrm:purge_tokens
```
Sau khi tạo tài khoản, staff liên kết tài khoản với hồ sơ nhân viên trong màn hình chỉnh sửa. Không có đăng ký công khai. Các vai trò: admin, hr, manager, employee. Admin xóa dữ liệu không có liên kết; HR quản lý nghiệp vụ; manager duyệt nghỉ toàn tổ chức; employee xem hồ sơ mình, nghỉ phép và chấm công.

## Kiến trúc quen thuộc với Laravel DJI

Mỗi module đã có ServiceProvider, Repository Interface, implementation Active Record, Application Command/Query và request allowlist. Controller/View điều phối và hiển thị; các thao tác đọc/ghi đi qua use case và repository. Xem [mapping DJI](docs/DJI_ARCHITECTURE_MAPPING.md) và [hướng dẫn .txt cho người chuyển từ Laravel](HUONG_DAN_LARAVEL_SANG_RAILS.txt).

```text
Route → Controller → Application Command/Query → Domain Repository Interface
                                                  ↓ (ServiceProvider binding)
                                 Infrastructure ActiveRecord Repository → Model → MySQL
```

`ruby bin/check-architecture` kiểm tra controller/view; `ruby bin/check-routes` giữ route tường minh.

## Cấu trúc Module (thư viện) + MVC

```text
modules/
  platform/    # Lớp nền, UI dùng chung, queue/cache/realtime/middleware
  identity/    # Authentication, tài khoản, API token
  workforce/   # Nhân viên, phòng ban
  attendance/  # Chấm công
  time_off/    # Nghỉ phép, email, thư viện Calendar
  payroll/     # Bảng lương
  recruitment/ # Tuyển dụng
  audit/       # Nhật ký, Observer
  dashboard/   # Tổng quan

modules/<module>/
  hrm_<module>.gemspec  # Thư viện local do Bundler quản lý
  app/models/          # Model
  app/views/           # View
  app/controllers/     # Controller
  app/policies/        # Phân quyền
  app/services/        # Nghiệp vụ
  app/jobs/, app/mailers/  # Khi module cần
  config/routes/       # Routing do module sở hữu
  lib/                 # Rails Engine + thư viện Ruby
  db/migrate/          # Migration mới của module
  test/                # Test module

config/                # Host cấu hình và ghép module
config/routes.rb       # Chỉ draw các fragment routing
db/migrate/           # Baseline lịch sử giữ nguyên cho database hiện có
test/integration/      # Hành trình xuyên module
test/modules_test.rb   # Tự nạp module tests khi chạy rails test
services/event_sink/   # Dịch vụ nhận sự kiện riêng
```

Mỗi module là một local gem Rails Engine được khai báo trong Gemfile. Host không còn chứa Model/View/Controller nghiệp vụ. Những lớp dùng chung nằm ở platform. Các module dùng chung MySQL, model constants và route helpers để giữ tương thích dữ liệu/API; không phải microservices độc lập. Không tạo bảng hoặc model giả cho module chỉ tổng hợp dữ liệu như dashboard.

Chạy toàn bộ kiểm thử bằng `bin/test-docker`. Chạy riêng module:
```sh
docker compose run --rm -e RAILS_ENV=test web bundle exec rails test modules/time_off/test
```

[Hướng dẫn module và ranh giới](docs/MODULES.md) · [Kiến trúc và ma trận tính năng](docs/ARCHITECTURE.md) · [API](docs/API.md) · [Kết quả kiểm tra](docs/VERIFICATION.md)

## Phạm vi thực tế
Có CRUD nhân sự/phòng ban, hồ sơ ứng viên và giai đoạn, một ca chấm công/ngày, nghỉ phép theo ngày lịch và số dư năm, chụp lương cơ bản/chốt kỳ lương, audit, realtime thông báo có thay đổi, email duyệt đơn và tổng hợp hằng ngày.

Đây là nền tảng phát triển chạy local, chưa phải giải pháp đã nghiệm thu để triển khai doanh nghiệp. Chưa có thuế/BHXH/OT, nhiều công ty, file hợp đồng, SSO/MFA, quên mật khẩu, ngày lễ/lịch ca hay phân quyền manager theo phòng ban. Rails là framework Ruby; dự án không trộn PHP vào backend. Microservice tách riêng là event receiver; các nghiệp vụ HRM giữ trong modular monolith để tránh phân tán giao dịch nhân sự.

## Đưa lên production
Dùng image có Gemfile.lock, build asset (`rails assets:precompile` với env phù hợp), HTTPS reverse proxy trước Puma, database/Redis private, SMTP thật, secrets manager; không dùng compose development nguyên trạng. Thiết lập `APP_HOST`, `DATABASE_NAME`, keys mã hóa, `SECRET_KEY_BASE`, `RAILS_ENV=production`; cấu hình allowed hosts/origins WebSocket. Seed demo bị khóa ở production. Backup cả database và khóa mã hóa, thử restore trước khi sử dụng dữ liệu thật.

## VS Code / Cmd + click

Mở thư mục gốc bằng VS Code rồi chọn **Dev Containers: Reopen in Container**. Ruby LSP tự cài trong container Ruby 3.4 để hỗ trợ Cmd+click/F12 tới định nghĩa class. Xem [hướng dẫn](docs/VSCODE.md).
