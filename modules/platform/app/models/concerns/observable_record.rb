module ObservableRecord # Module chứa logic theo dõi Model
  extend ActiveSupport::Concern # Hỗ trợ tái sử dụng module trong nhiều Model
  included do # Đăng ký callback khi Model include Concern
    after_create { Hrm::RecordObserver.record(self, "created") } # Chạy sau khi tạo bản ghi  # self : Đối tượng Model hiện tại
    after_update { Hrm::RecordObserver.record(self, "updated") } # Chạy sau khi cập nhật bản ghi  # self : Đối tượng Model hiện tại
    after_destroy { Hrm::RecordObserver.record(self, "deleted") } # Chạy sau khi xóa bản ghi  # self : Đối tượng Model hiện tại
    after_commit { Hrm::RecordObserver.committed(self) } # Chạy sau khi transaction commit thành công  # self : Đối tượng Model hiện tại
  end
end

# Đoạn code này trong Ruby on Rails là một ActiveSupport::Concern dùng để theo dõi các thay đổi của Model bằng Active Record Callbacks.#

# Nó khá giống Observer Pattern + Eloquent Model Events trong Laravel.#

# Trong hệ thống HRM, cơ chế này có thể được sử dụng để ghi Audit Log, tạo sự kiện Outbox hoặc kích hoạt những xử lý sau khi dữ liệu thay đổi.

# 2. Luồng hoạt động thực tế
# Ví dụ một nhân viên được cập nhật thông tin:

# Employee.update(...)
# Rails cập nhật dữ liệu nhân viên
#      v
# after_update
# RecordObserver.record(employee, "updated")
#      v
# Database Transaction Commit
# Xác nhận thay đổi thành công
#      v
# after_commit
# RecordObserver.committed(employee)

# Nếu transaction bị rollback, after_commit sẽ không chạy cho transaction đó.
