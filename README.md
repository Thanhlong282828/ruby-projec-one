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
docker compose exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS hrm_test; GRANT ALL ON hrm_test.* TO ruby;"'
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

Đây là nền tảng phát triển chạy local, chưa phải giải pháp đã nghiệm thu để triển khai doanh nghiệp. Chưa có thuế/BHXH/OT đầy đủ, file hợp đồng, SSO/MFA, quên mật khẩu, ngày lễ và branch ABAC hay phân quyền manager theo phòng ban. Rails là framework Ruby; dự án không trộn PHP vào backend. Microservice tách riêng là event receiver; các nghiệp vụ HRM giữ trong modular monolith để tránh phân tán giao dịch nhân sự.

## Đưa lên production
Dùng image có Gemfile.lock, build asset (`rails assets:precompile` với env phù hợp), HTTPS reverse proxy trước Puma, database/Redis private, SMTP thật, secrets manager; không dùng compose development nguyên trạng. Thiết lập `APP_HOST`, `DATABASE_NAME`, keys mã hóa, `SECRET_KEY_BASE`, `RAILS_ENV=production`; cấu hình allowed hosts/origins WebSocket. Seed demo bị khóa ở production. Backup cả database và khóa mã hóa, thử restore trước khi sử dụng dữ liệu thật.

## VS Code / Cmd + click

Mở thư mục gốc bằng VS Code rồi chọn **Dev Containers: Reopen in Container**. Ruby LSP tự cài trong container Ruby 3.4 để hỗ trợ Cmd+click/F12 tới định nghĩa class. Xem [hướng dẫn](docs/VSCODE.md).


## Company & RBAC MySQL (28/10/2026)

Một định danh đăng nhập có nhiều membership theo company; mỗi User profile vẫn thuộc đúng một company; `company_roles`, `permissions`, `role_permissions` và `user_permissions` lưu quyền thật trong MySQL. Vai trò tùy chỉnh không cần sửa enum. Web `/manage/company`, `/manage/roles`, `/manage/accounts`; REST `/api/v1/company`, `/api/v1/roles`, `/api/v1/accounts`. `User#allowed?` đọc DB, Policy kiểm permission và company; các scope, payroll, cache, email, audit/outbox và realtime đều giới hạn tenant. Hướng dẫn: [Company & permission](HUONG_DAN_COMPANY_PERMISSION_MYSQL.txt) ở gốc project.

## MySQL qua phpMyAdmin (local)

Mở http://pma.test/, tài khoản `ruby`, mật khẩu `123456`. Chọn database `hrm_development`: Rails đọc/ghi trực tiếp database này bằng cùng tài khoản trong `.env`; phpMyAdmin là giao diện quản trị. Database `hrm_test` dành riêng cho kiểm thử. Không nhập tài khoản này vào form đăng nhập HRM. Mật khẩu này chỉ dùng local; MySQL Ruby mở cổng 13306 chỉ trên localhost.

Trong phpMyAdmin chọn server Ruby HRM (127.0.0.1:13306). Rails trong Docker vẫn kết nối mysql:3306 tới cùng database. Server MySQL local (existing) giữ nguyên kết nối cũ 3306.

## Organization — CQRS (11/11/2026)

Module `organization` bổ sung trung tâm chi phí, cây tổ chức, vị trí, phân công nhân sự theo hiệu lực, định biên và CSV. Dữ liệu MySQL thật theo company, có quyền DB và kiểm thử concurrent vacancy. Mở `/organization/tree` hoặc `/organization/cost-centers`. Không seed/copy dữ liệu vận hành Laravel.

[Hướng dẫn Laravel ↔ Ruby cho Organization](HUONG_DAN_ORGANIZATION_CQRS_LARAVEL_RUBY.txt) · [Kiểm kê toàn bộ DJI và phần chưa chuyển](DOI_CHIEU_TOAN_BO_LARAVEL_DJI_SANG_RUBY.txt). Đây là một bước chuyển, chưa phải tương đương toàn bộ DJI.

## Đối chiếu chức năng cấu hình Laravel DJI → Ruby

Chạy `ruby bin/audit-env-features` để thống kê tên biến và tham chiếu source, hoặc thêm `--write` để cập nhật `DOI_CHIEU_ENV_LARAVEL_DJI_RUBY.txt` và `docs/env-feature-audit.json`. Lệnh chỉ đọc tên/tham chiếu, không load/eval `.env`, không xuất giá trị và không liên hệ dịch vụ bên ngoài. Source mặc định: `Desktop/laraveldji/admin`; có thể truyền `--laravel-root PATH`.

TXT có ba bảng ngang theo nhóm chức năng, từng biến Laravel và code đọc biến Ruby. Mapping có review ở `docs/env-feature-map.json`; các khoảng trống Cloudflare/Supabase/S3/ClamAV/OAuth/monitoring được nối vào `docs/erp-porting-roadmap.json`. Có tên biến hoặc reference không chứng minh dịch vụ đã được kích hoạt/kiểm chứng.

## Integration Hub / webhook inbound

Mở `/integration` trong nhóm Quản trị & bảo mật. Có connection lifecycle, secret mã hóa và trả một lần, HMAC timestamp/event ID/raw body, encrypted inbox, metadata/payload permissions riêng và review có khóa phiên bản. Dashboard có KPI dẫn tới Hub; ba KPI trong Hub lọc đúng trạng thái. Hướng dẫn so sánh: `HUONG_DAN_INTEGRATION_WEBHOOK_LARAVEL_RUBY.txt`.

Public ingress `/webhooks/integration/:public_id` chỉ dùng HMAC riêng từng connection; không dùng cookie/company từ client. Kết nối mới tạm dừng. Inbound acknowledgment không tự áp dụng nghiệp vụ; outbound provider adapters/attempts/retry/DLQ/replay và retention scheduling vẫn chưa port. `.env` không chứa secret từng connection; không copy khóa DJI.

### Outbound Integration

Open `/integration` → Hàng đợi gửi, or `/integration/outbound`. Durable MySQL queue, attempt history, Sidekiq delivery/scheduler, retry/backoff and dead-letter replay are available under company-scoped database permissions. External targets are disabled by default (`INTEGRATION_TARGETS_JSON={}`); no arbitrary browser-supplied URLs. Read `HUONG_DAN_OUTBOUND_QUEUE_LARAVEL_RUBY.txt` before configuring a partner. Provider-specific exports and automatic business dispatch remain incomplete.

### Integration operational audit

Open `/integration/audit` from the Integration subnavigation. Dedicated company-scoped grant, safe metadata projection, period/resource/record/action filters, keyset pagination and source links are implemented. See `HUONG_DAN_AUDIT_INTEGRATION_LARAVEL_RUBY.txt` for the Laravel comparison and differences from DJI delivery audit/history. This does not add historical before/after values or a tamper-proof ledger.

### Payroll reconciliation CSV

`/payroll/exports` provides immutable, encrypted CSV snapshots from finalized pay runs with separate download grants, integrity checks and access history. Read `HUONG_DAN_XUAT_BANG_LUONG_LARAVEL_RUBY.txt`. This adds a source-artifact prerequisite; accounting journals/provider mappings/outbound bridge remain incomplete.

Multi-company: `/system/companies` là danh mục quản trị tổng (SystemGrant riêng), `/my/companies` chọn membership của một login identity, `/organization/branches` quản lý nhiều chi nhánh trong company hiện tại. Quyền business vẫn theo profile/role/overrides từng company; không flip user.company_id hoặc copy password. Chi nhánh dùng OrganizationUnit thật, chưa có ABAC giới hạn từng branch xuyên ERP. Đọc HUONG_DAN_NHIEU_CONG_TY_CHI_NHANH_LARAVEL_RUBY.txt ở gốc repo.
Schema chuẩn: db/structure.sql giữ MySQL trigger; local/CI dùng bin/prepare-mysql-tls, bin/migrate-docker và bin/test-docker. Không dùng app user để tạo trigger hoặc tự load test schema. Production phải cấu hình CA/migration role/secrets riêng; chưa deploy cloud thật.

## Kiểm tra chất lượng trên GitHub

Push/PR chạy hai job: Ruby/Rails lint-format và MySQL test/autoload/security. Cấu hình thật trong `.github/workflows/ci.yml`; lệnh local `docker compose exec -T web ruby bin/quality`. Xem [đối chiếu Pint/Larastan/PHPStan và giới hạn](docs/QUALITY.md). RuboCop không thay thế static type checking PHPStan level10; remote Actions/branch protection chưa được xác nhận.
