class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end


# Đoạn code này trong Ruby on Rails là ApplicationJob, lớp cha dùng chung cho các Background Jobs (tác vụ chạy nền).

# Nó tương đương với việc bạn tạo một BaseJob trong Laravel để các Job khác kế thừa.
