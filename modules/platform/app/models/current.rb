class Current < ActiveSupport::CurrentAttributes # ActiveSupport::CurrentAttributes : Đây là lớp Rails hỗ trợ lưu các thuộc tính ngữ cảnh hiện tại, được cô lập theo luồng thực thi (thread hoặc fiber tùy cơ chế isolation của Rails).
  attribute :user # Khai báo một thuộc tính tên user, giúp Rails tạo các phương thức truy cập: Current.user  Current.user = employee
end   # Đây không phải cột database, cũng không phải quan hệ belongs_to. Nó chỉ là thuộc tính lưu ngữ cảnh đang xử lý.
#
# Đoạn code này trong Ruby on Rails dùng để lưu thông tin người dùng hiện tại (Current.user) trong phạm vi xử lý một request.
# Nó rất hữu ích trong hệ thống HRM/ERP khi nhiều Controller, Service, Model hoặc Observer cần biết ai đang thực hiện hành động mà không phải truyền current_user qua từng phương thức.

#  A. ActiveSupport::CurrentAttributes
#        class Current < ActiveSupport::CurrentAttributes
#  Đây là lớp Rails hỗ trợ lưu các thuộc tính ngữ cảnh hiện tại, được cô lập theo luồng thực thi (thread hoặc fiber tùy cơ chế isolation của Rails).
#  Ví dụ:
#        Current.user = employee
#  Sau đó, ở nơi khác trong cùng ngữ cảnh thực thi:
#        Current.user
#        Current.user.id
#        Current.user.company_id
#  Không cần truyền employee vào từng hàm.

# B. attribute :user
#         attribute :user
# Khai báo một thuộc tính tên user, giúp Rails tạo các phương thức truy cập:
#        Current.user
#        Current.user = employee
# Đây không phải cột database, cũng không phải quan hệ belongs_to.
# Nó chỉ là thuộc tính lưu ngữ cảnh đang xử lý.

#
#   2. Ví dụ thực tế trong HRM
# Trước đó bạn đã có đoạn trong ApplicationController:
#           before_action { Current.user = current_user }
# Giả sử nhân viên đăng nhập và sửa đơn nghỉ phép:
#        Request từ User ID 15
#        PATCH /leave_requests/10
#                   v
#        ApplicationController
#        Current.user = current_user
#                   v
#        LeaveRequest / ObservableRecord
#        after_update gọi RecordObserver
#                   v
#              Audit Log
#        Có thể lấy Current.user.id = 15

# Ví dụ trong Observer:
#        class Hrm::RecordObserver
#          def self.record(record, action)
#            actor_id = Current.user&.id

#            # Ghi nhận actor_id, action, record...
#          end
#        end
# Ký hiệu &. là Safe Navigation trong Ruby, tương tự ?-> trong PHP. Nếu Current.user là nil, kết quả sẽ là nil thay vì phát sinh lỗi.
# Lưu ý: Đây là ví dụ cách sử dụng, chưa khẳng định Hrm::RecordObserver hiện tại của bạn đã ghi Audit Log theo cách này.

# 3. Current.user khác current_user thế nào?
#  current_user	                                        Current.user
#  Thường là phương thức trong Controller       	Thuộc tính ngữ cảnh của Rails
#  Lấy user từ Session/Token	                    Chứa user đã được gán                        <
#  Gắn với logic xác thực                         	Không tự xác thực
#  Gọi current_user trong Controller	            Có thể đọc Current.user ở nhiều lớp

# Ví dụ:
#       # Controller
#       Current.user = current_user

#       # Service
#       actor = Current.user

#       # Observer
#       actor_id = Current.user&.id

# Điểm quan trọng: Current.user không tự biết ai đang đăng nhập. Phải có code gán giá trị cho nó.          <

# 4. Có giống Laravel không?
# Gần giống việc bạn gọi:
#             auth()->user();             <
# Nhưng có sự khác biệt:
#   - Laravel auth()->user() truy cập người dùng thông qua Authentication Guard.            <
#   - Rails Current.user chỉ đọc thuộc tính đã được gán trong ngữ cảnh hiện tại.            <
# Vì vậy, Current.user gần với một request context holder hơn là hệ thống Authentication.

# 5. Những lưu ý quan trọng
# Không phải biến global dùng chung cho mọi user. Hai request đồng thời được cô lập theo cơ chế execution context của Rails, nên không mặc định chia sẻ cùng Current.user.

# Phải reset đúng vòng đời. Rails hỗ trợ reset CurrentAttributes thông qua executor trong các luồng request/job được quản lý. Với thread tự tạo hoặc xử lý tùy chỉnh, cần quản lý ngữ cảnh rõ ràng để tránh lưu giá trị cũ.

# Background Job không tự nhận user từ HTTP request.

# Ví dụ:
# SomeJob.perform_later


# Không nên giả định bên trong Job có Current.user của người gửi request. Nếu cần người thực hiện, nên truyền user_id vào Job và xác định lại user khi xử lý.

# Không dùng Current.user thay cho Authorization. Vẫn cần kiểm tra quyền và Company/Tenant scope qua Pundit, Policy hoặc lớp nghiệp vụ tương ứng.


# Kết luận: Current < ActiveSupport::CurrentAttributes là nơi lưu ngữ cảnh hiện tại của ứng dụng.
# Trong HRM, nó đặc biệt hữu ích cho Audit Log, Observer và Service cần biết ai đang thao tác, nhưng không thay thế Authentication, Authorization hoặc cơ chế bảo vệ Multi-Tenant.


# Ví dụ dễ nhớ
#             user = current_user
# Nghĩa là: Tôi lấy user để dùng trong phương thức này.
#             Current.user = current_user
# Nghĩa là: Tôi đặt user vào ngữ cảnh hiện tại để các thành phần khác có thể đọc được.



# ========================================================================================================================================
#       1. RAILS KHÔNG CURRENT.USER                 |       2. RAILS CÓ CURRENT.USER                    |       3. LARAVEL AUTH()
# ========================================================================================================================================
#                                                  |                                                 |
#  [CẤU HÌNH BAN ĐẦU]                              |  [CẤU HÌNH BAN ĐẦU]                              |  [CẤU HÌNH BAN ĐẦU]
#                                                  |                                                 |
#  Không cần Current                               |  class Current < ActiveSupport::CurrentAttributes|  Laravel Auth Guard
#                                                  |    attribute :user                              |  Quản lý user đã đăng nhập
#                                                  |  end                                            |
#                                                  |                                                 |
#                                                  |  # Trong ApplicationController                  |
#                                                  |  before_action { Current.user = current_user } |
#                                                  |                                                 |
# ========================================================================================================================================
#  TẦNG 1: CONTROLLER                              |  TẦNG 1: CONTROLLER                              |  TẦNG 1: CONTROLLER
# ========================================================================================================================================
#                                                  |                                                 |
#  class SalaryController < ApplicationController  |  class SalaryController < ApplicationController |  class SalaryController extends Controller
#    def update                                    |    def update                                   |  {
#      user = current_user                         |      SalaryService.new.update_salary(100)       |      public function update()
#      SalaryService.new.update_salary(100, user)  |    end                                          |      {
#    end                                           |  end                                            |          app(SalaryService::class)
#  end                                             |                                                 |              ->updateSalary(100);
#                                                  |                                                 |      }
#  # Phải truyền user xuống Service                |  # Không truyền user                            |  }
#                                                  |                                                 |  # Không truyền user
# ========================================================================================================================================
#  TẦNG 2: SERVICE                                 |  TẦNG 2: SERVICE                                 |  TẦNG 2: SERVICE
# ========================================================================================================================================
#                                                  |                                                 |
#  class SalaryService                             |  class SalaryService                            |  class SalaryService
#    def update_salary(salary_id, user)             |    def update_salary(salary_id)                 |  {
#      SalaryRepository.new                        |      SalaryRepository.new                       |      public function updateSalary(int $id)
#        .update_salary(salary_id, user)            |        .update_salary(salary_id)                |      {
#    end                                           |    end                                          |          app(SalaryRepository::class)
#  end                                             |  end                                            |              ->updateSalary($id);
#                                                  |                                                 |      }
#  # Nhận user rồi truyền tiếp                     |  # Không cần nhận user                          |  }
#                                                  |                                                 |  # Không cần nhận user
# ========================================================================================================================================
#  TẦNG 3: REPOSITORY                              |  TẦNG 3: REPOSITORY                              |  TẦNG 3: REPOSITORY
# ========================================================================================================================================
#                                                  |                                                 |
#  class SalaryRepository                          |  class SalaryRepository                         |  class SalaryRepository
#    def update_salary(salary_id, user)             |    def update_salary(salary_id)                 |  {
#      salary = Salary.find(salary_id)              |      salary = Salary.find(salary_id)            |      public function updateSalary(int $id)
#                                                  |                                                 |      {
#      salary.update!(amount: 20_000_000)          |      salary.update!(amount: 20_000_000)         |          $salary = Salary::findOrFail($id);
#                                                  |                                                 |
#      AuditService.record(salary, user)           |      AuditService.record(salary)                |          $salary->update([
#    end                                           |    end                                          |              'amount' => 20000000,
#  end                                             |  end                                            |          ]);
#                                                  |                                                 |
#  # Vẫn phải truyền user xuống AuditService       |  # Không truyền user                            |          app(AuditService::class)
#                                                  |                                                 |              ->record($salary);
#                                                  |                                                 |      }
#                                                  |                                                 |  }
#                                                  |                                                 |  # Không truyền user
# ========================================================================================================================================
#  TẦNG 4: AUDIT SERVICE                           |  TẦNG 4: AUDIT SERVICE                           |  TẦNG 4: AUDIT SERVICE
# ========================================================================================================================================
#                                                  |                                                 |
#  class AuditService                              |  class AuditService                             |  class AuditService
#    def self.record(salary, user)                  |    def self.record(salary)                      |  {
#      AuditLog.create!(                            |      AuditLog.create!(                           |      public function record(Salary $salary)
#        user_id: user.id,                          |        user_id: Current.user.id,                |      {
#        action: "updated",                         |        action: "updated",                       |          AuditLog::create([
#        record_id: salary.id                       |        record_id: salary.id                     |              'user_id' => auth()->id(),
#      )                                           |      )                                          |              'action' => 'updated',
#    end                                           |    end                                          |              'record_id' => $salary->id,
#  end                                             |  end                                            |          ]);
#                                                  |                                                 |      }
#  # Lấy user.id từ tham số                        |  # Lấy Current.user.id từ context               |  }
#                                                  |                                                 |  # Lấy auth()->id() từ Auth Guard
# ========================================================================================================================================
#  LUỒNG XỬ LÝ                                    |  LUỒNG XỬ LÝ                                    |  LUỒNG XỬ LÝ
# ========================================================================================================================================
#                                                  |                                                 |
#  Controller                                      |  ApplicationController                          |  Laravel Auth Guard
#    user = current_user                           |    Current.user = current_user                  |    User ID = 15
#           |                                      |           |                                     |           |
#           v                                      |           v                                     |           v
#  SalaryService(id, user)                         |  SalaryController                              |  SalaryController
#           |                                      |    update_salary(id)                            |    updateSalary(id)
#           v                                      |           |                                     |           |
#  SalaryRepository(id, user)                      |           v                                     |           v
#           |                                      |  SalaryService(id)                              |  SalaryService(id)
#           v                                      |           |                                     |           |
#  AuditService(salary, user)                      |           v                                     |           v
#           |                                      |  SalaryRepository(id)                           |  SalaryRepository(id)
#           v                                      |           |                                     |           |
#  user.id = 15                                    |           v                                     |           v
#                                                  |  AuditService                                   |  AuditService
#                                                  |    Current.user.id = 15                         |    auth()->id() = 15
#                                                  |                                                 |
# ========================================================================================================================================
#  KẾT QUẢ                                        |  KẾT QUẢ                                        |  KẾT QUẢ
# ========================================================================================================================================
#                                                  |                                                 |
#  AuditLog(user_id: 15)                           |  AuditLog(user_id: 15)                          |  AuditLog(user_id: 15)
#                                                  |                                                 |
#  Truyền user qua nhiều tầng                      |  Không truyền user qua các tầng                 |  Không truyền user qua các tầng
#  Phụ thuộc tường minh                            |  Dùng CurrentAttributes                         |  Dùng Authentication Guard
#  Dễ nhìn thấy dữ liệu đầu vào                    |  Phải gán Current.user trước                    |  Phải có guard xác thực phù hợp
#                                                  |                                                 |
# ========================================================================================================================================
