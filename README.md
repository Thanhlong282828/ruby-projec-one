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
docker compose run --rm web bundle exec brakeman --no-pager
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

## Cấu trúc
```text
app/controllers/{workforce,time_off,payroll,recruitment,api/v1}
app/models                 # Active Record + validation
app/services/{hrm,time_off,payroll}
app/policies               # Authorization
app/jobs, app/mailers, app/channels
app/views                  # ERB theo module MVC
config/initializers        # queue, scheduler, cache, middleware, encryption
services/event_sink        # Python stdlib, HMAC receiver + SQLite dedup
test                       # model/service/API/web/job tests
db/migrate, db/seeds.rb
docs                       # kiến trúc và API
```

[Kiến trúc và ma trận tính năng](docs/ARCHITECTURE.md) · [API](docs/API.md) · [Kết quả kiểm tra](docs/VERIFICATION.md)

## Phạm vi thực tế
Có CRUD nhân sự/phòng ban, hồ sơ ứng viên và giai đoạn, một ca chấm công/ngày, nghỉ phép theo ngày lịch và số dư năm, chụp lương cơ bản/chốt kỳ lương, audit, realtime thông báo có thay đổi, email duyệt đơn và tổng hợp hằng ngày.

Đây là nền tảng phát triển chạy local, chưa phải giải pháp đã nghiệm thu để triển khai doanh nghiệp. Chưa có thuế/BHXH/OT, nhiều công ty, file hợp đồng, SSO/MFA, quên mật khẩu, ngày lễ/lịch ca hay phân quyền manager theo phòng ban. Rails là framework Ruby; dự án không trộn PHP vào backend. Microservice tách riêng là event receiver; các nghiệp vụ HRM giữ trong modular monolith để tránh phân tán giao dịch nhân sự.

## Đưa lên production
Dùng image có Gemfile.lock, build asset (`rails assets:precompile` với env phù hợp), HTTPS reverse proxy trước Puma, database/Redis private, SMTP thật, secrets manager; không dùng compose development nguyên trạng. Thiết lập `APP_HOST`, `DATABASE_NAME`, keys mã hóa, `SECRET_KEY_BASE`, `RAILS_ENV=production`; cấu hình allowed hosts/origins WebSocket. Seed demo bị khóa ở production. Backup cả database và khóa mã hóa, thử restore trước khi sử dụng dữ liệu thật.
