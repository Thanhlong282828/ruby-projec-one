require "yaml"    # A. Nạp thư viện YAML - Dùng để đọc các file .yml hoặc .yaml, thường chứa cấu hình lịch chạy Job.

Sidekiq.configure_server do |config|  # B. Cấu hình Sidekiq Server = php artisan queue:work Laravel
  config.redis = { url: ENV.fetch("REDIS_URL") } # B. Cấu hình Sidekiq Server - configure_server: Cấu hình tiến trình Sidekiq xử lý Job. - config.redis: Chỉ định Redis mà Sidekiq sử dụng. - ENV.fetch("REDIS_URL"): Lấy URL Redis từ biến môi trường.
  config.on(:startup) do # C. Chạy khi Sidekiq khởi động
    schedules = Array(Rails.application.config.x.hrm.schedule_files).each_with_object({}) do |path, result|   # D. Đọc và gộp nhiều file lịch
      YAML.safe_load_file(path).each do |name, attributes|
        raise "Duplicate scheduled job: #{name}" if result.key?(name)
        result[name] = attributes
      end # Giả sử Rails được cấu hình hai file: config/schedule/attendance.yml   attendance_daily:cron: "0 23 * * *" class: "AttendanceDailyJob"   config/schedule/salary.yml: salary_monthly: cron: "0 0 1 * *"  class: "SalaryMonthlyJob"
    end # Đoạn Ruby sẽ đọc cả hai file rồi gộp thành một Hash: {"attendance_daily" => {"cron" => "0 23 * * *","class" => "AttendanceDailyJob" },"salary_monthly" => {"cron" => "0 0 1 * *","class" => "SalaryMonthlyJob" }}
    Sidekiq::Cron::Job.load_from_hash(schedules) # E. Đăng ký các Cron Job  |  Sidekiq-Cron	  Laravel Scheduler  |   Đây là dòng quan trọng nhất. Nó đưa danh sách lịch đã đọc vào Sidekiq-Cron để quản lý.    |   Ví dụ, attendance_daily có lịch: cron: "0 23 * * *"   |   Nghĩa là 23:00 mỗi ngày theo múi giờ được áp dụng cho lịch. Khi đến giờ, Sidekiq-Cron sẽ enqueue Job để Sidekiq Worker xử lý. Dòng load_from_hash không trực tiếp thực thi toàn bộ Job ngay khi startup.
  end
end

Sidekiq.configure_client { |config| config.redis = { url: ENV.fetch("REDIS_URL") } } # F. Cấu hình Sidekiq Client  |  SomeJob::dispatch() Laravel  |  Client là phía đẩy Job vào Redis.
#
# Đoạn code Ruby này đang cấu hình Sidekiq kết nối Redis và tự động đăng ký các công việc chạy theo lịch (Cron Jobs) khi Sidekiq Server khởi động.

# Nếu so sánh với Laravel, nó gần giống việc kết hợp:         <
# Laravel Queue Worker: Xử lý Job chạy nền.
# Redis: Lưu hàng đợi Job.
# Laravel Scheduler: Định nghĩa Job chạy theo lịch.
# Sidekiq-Cron: Tự động đưa Job vào hàng đợi theo lịch đã cấu hình.        <

# 1. Luồng hoạt động tổng thể
# Khởi động Sidekiq Server
# Sidekiq.configure_server
#     v
# Kết nối Redis
# ENV.fetch("REDIS_URL")
#     v
# Đọc các file YAML của HRM
# config.x.hrm.schedule_files
#     v
# Gộp lịch và kiểm tra tên trùng
# raise nếu có Duplicate scheduled job
#     v
# Đăng ký lịch chạy Sidekiq-Cron
# Sidekiq::Cron::Job.load_from_hash(schedules)

# Đến giờ → Enqueue Job → Worker xử lý
# Ruby on Rails	              Laravel
# Sidekiq Server          	php artisan queue:work
# Sidekiq Client          	SomeJob::dispatch()           Client là phía đẩy Job vào Redis.
# Sidekiq-Cron            	Laravel Scheduler             Sidekiq-Cron sẽ enqueue Job để Sidekiq Worker xử lý
# perform_async           	dispatch()
# Redis	                    Redis Queue
# YAML schedule files     	Khai báo lịch trong routes/console.php hoặc nơi cấu hình Scheduler
# config.on(:startup)     	Callback khi Sidekiq Server khởi động; không tương đương trực tiếp với AppServiceProvider::boot()
