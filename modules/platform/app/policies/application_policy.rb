class ApplicationPolicy
  attr_reader :user, :record # Tự động tạo hai phương thức đọc:  user record  |  Tương tự PHP:  class ApplicationPolicy { public function __construct( protected User $user,protected Salary $record ) {} }  |  Ở Ruby, attr_reader tạo getter; nó không tự tạo setter.
  def initialize(user, record) = (@user, @record = user, record) # Đây initialize là >  Constructor   < | Ví dụ: policy = SalaryPolicy.new(user, salary) | @user: Người đang yêu cầu thao tác. @record: Đối tượng cần kiểm tra quyền. | record có thể là một bản ghi như Salary.find(100) hoặc một lớp như Salary.
  def index? = false   # C. Mặc định tất cả đều false   index?	  Xem danh sách   |   Tất cả đều từ chối, trừ khi Policy con ghi đè. |     class SalaryPolicy < ApplicationPolicy
  def show? = false    # C. Mặc định tất cả đều false   show?	    Xem chi tiết    |   Tất cả đều từ chối, trừ khi Policy con ghi đè. |        def update?
  def create? = false  # C. Mặc định tất cả đều false   create?	  Tạo             |   Tất cả đều từ chối, trừ khi Policy con ghi đè. |               allowed?("salary.update")
  def update? = false  # C. Mặc định tất cả đều false   update?	  Cập nhật        |   Tất cả đều từ chối, trừ khi Policy con ghi đè. |        end
  def destroy? = false # C. Mặc định tất cả đều false   destroy?	Xóa             |   Tất cả đều từ chối, trừ khi Policy con ghi đè. |      end   # Khi đó chỉ update? được định nghĩa lại, các quyền còn lại vẫn mặc định false.
  def new? = create?   # D. Quyền mở trang tạo mới sử dụng kết quả create?.
  def edit? = update?  # D. Quyền mở trang tạo mới sử dụng kết quả update?.
  protected # Phần quan trọng: allowed? và same_company?  |  Ví dụ: allowed?("salary.update")   |  Phải thỏa mãn cả hai điều kiện.
  def allowed?(key) = user&.allowed?(key) && same_company? # Thử mô phỏng phân quyền | [v] User có quyền salary.update [v] Salary thuộc cùng Company với User   |  Cho phép cập nhật : allowed? = true && true = true > nếu thiếu 1 điều kiện: [x] Từ chối cập nhật allowed? = true && false = false
  def same_company? = record.is_a?(Class) || (user && record.company_id == user.company_id) # Hàm kiểm tra Company: Có hai trường hợp:
  # 1 : record là Class : | authorize Salary  | record.is_a?(Class) trả về true, nên same_company? không kiểm tra company_id. | Điều này thường phục vụ các thao tác cấp lớp như tạo mới. Tuy nhiên, bản thân điều kiện này không chứng minh một bản ghi được tạo sau đó thuộc đúng Company.
  # 2 : record là bản ghi : | authorize salary, :update?  | Lúc này so sánh: record.company_id == user.company_id  |  Nếu khác nhau thì từ chối. |- Một lưu ý bảo mật: same_company? cho phép trường hợp record là Class, và không tự kiểm tra user.active? hoặc user.company.active?. Vì vậy, cần xác nhận user.allowed? và tầng Authentication xử lý các điều kiện đó phù hợp.
  class Scope # Scope dùng để bảo vệ danh sách dữ liệu  | Đây là phần rất quan trọng trong Multi-Tenant:  | tenant làm gì?
    attr_reader :user, :scope
    def initialize(user, scope) = (@user, @scope = user, scope)
    def tenant = user&.active? && user.company&.active? ? scope.where(company_id: user.company_id) : scope.none # Ví dụ: scope.where(company_id: user.company_id) | Nếu User 15 thuộc Company 10: SELECT * FROM salaries WHERE company_id = 10;  |  Nếu User hoặc Company không hoạt động: scope.none  > Trả về một relation rỗng.
    def resolve = scope.none # Vì sao resolve = scope.none? | Nghĩa là mặc định không trả về bản ghi nào. | Policy con phải chủ động định nghĩa phạm vi được phép truy cập.
  end
end
# Đoạn code này là ApplicationPolicy trong Ruby on Rails, sử dụng Pundit để phân quyền (Authorization) và bảo vệ dữ liệu Multi-Tenant.

# Trong Laravel, nó tương đương với Policy + Permission + giới hạn truy vấn theo company_id.#

# Đây là lớp Policy cha, được thiết kế theo nguyên tắc mặc định từ chối tất cả quyền (Deny by Default).

# 2. ApplicationPolicy dùng để làm gì?
# Giả sử hệ thống HRM có hai công ty:
#      - Company 10: Nhân viên A, B, C.
#      - Company 20: Nhân viên D, E, F.
# User 15 thuộc Company 10 và có quyền salary.update.

# Khi User 15 sửa Salary 100, hệ thống cần kiểm tra hai điều kiện:
#      1. User có quyền salary.update không?
#      2. Salary 100 có thuộc Company 10 không?
# Nếu thiếu một trong hai điều kiện, phải từ chối.

# Đó chính là ý tưởng của:
#     def allowed?(key)
#       user&.allowed?(key) && same_company?
#     end


# 2. Pundit xử lý như thế nào?
#  Vì sao resolve = scope.none?         <  ApplicationPolicy::Scope
#      def resolve
#        scope.none
#      end
#  Nghĩa là mặc định không trả về bản ghi nào.
#  Policy con phải chủ động định nghĩa phạm vi được phép truy cập.
#  Ví dụ:
#  Model:
#        class Salary < ApplicationRecord             <
#           include CompanyOwned
#        end
#  Policy:
#       class SalaryPolicy < ApplicationPolicy          <  Đúng. SalaryPolicy được Pundit tự động ánh xạ với Model Salary theo quy ước đặt tên (Naming Convention).  |  Bạn không cần khai báo thủ công quan hệ giữa hai lớp nếu sử dụng đúng quy ước của Pundit.
#         class Scope < ApplicationPolicy::Scope
#           def resolve
#             return scope.none unless user&.allowed?("salary.view")
#             tenant
#           end
#         end
#       end
#  Trong Controller:                          <
#       class SalariesController < ApplicationController
#         def index
#           @salaries = policy_scope(Salary)                              <  sao có (Salary) ?  |  Vì Salary là tên Model (Class) mà bạn muốn Pundit lọc dữ liệu theo quyền của người dùng.  |  1. Tại sao phải truyền (Salary)?
#                                                  Bạn hiểu đơn giản:              policy_scope: Phương thức của Pundit.
#                                                   policy_scope(Salary)           Salary: Model cần lọc.     - @salaries: Biến chứa kết quả để Controller sử dụng.
#                                                  Có nghĩa là: Pundit ơi, hãy lấy danh sách Salary mà người dùng hiện tại được phép xem.                                 <
#         end
#       end
#  Lúc này danh sách Salary được giới hạn theo Company nếu user đủ điều kiện.
#  Điểm cần nhớ: Phương thức tenant không tự động chạy. resolve của Policy con phải gọi nó, và Controller cần sử dụng policy_scope hoặc cơ chế tương đương.


# 6. So sánh Rails Pundit và Laravel Policy
#     Rails Pundit                      	Laravel
#     ApplicationPolicy	              Base Policy tự định nghĩa
#     initialize(user, record)      	Laravel truyền User và đối tượng vào Policy method
#     update?	                        update(User $user, Salary $salary)                              <
#     user.allowed?(key)            	$user->can($permission)
#     same_company?                 	So sánh $salary->company_id                               <
#     Scope#resolve                 	Query Scope / Repository / Tenant Scope
#     authorize salary              	$this->authorize('update', $salary)

# Ví dụ Laravel:
# class SalaryPolicy
# {
#     public function update(User $user, Salary $salary): bool
#     {
#         return $user->can('salary.update')
#             && $salary->company_id === $user->company_id;
#     }
# }
# Controller:
# class SalaryController extends Controller
# {
#     public function update(Salary $salary)
#     {
#        $this->authorize('update', $salary);
#
#         // Cập nhật Salary sau khi được phép
#     }
# }

#
# Để lọc danh sách theo Company trong Laravel, cần thêm query scope hoặc cơ chế tenant isolation riêng. Policy kiểm tra một bản ghi không tự động lọc toàn bộ truy vấn.



#    RUBY: update?	   Laravel   update(User $user, Salary $salary)        nếu module khác gọi update? không phải Salary thì nó sẽ chuyển theo name model ?
#    Đúng. Pundit sẽ dựa vào Model được truyền vào authorize để xác định Policy tương ứng, chứ không dựa vào Controller hoặc Module đang gọi.
# Ví dụ: SalaryPolicy, EmployeePolicy, LeaveRequestPolicy đều có thể định nghĩa phương thức update?, nhưng Pundit sẽ chọn đúng Policy theo Model.
#  1. Ví dụ ba Model cùng có update?
#      class SalaryPolicy < ApplicationPolicy
#        def update?
#          allowed?("salary.update")
#        end
#      end

#      class EmployeePolicy < ApplicationPolicy
#        def update?
#          allowed?("employee.update")
#        end
#      end

#      class LeaveRequestPolicy < ApplicationPolicy
#        def update?
#          allowed?("leave_request.update")
#        end
#      end

#      Khi gọi:
#           authorize Salary.find(1), :update?                        < find(1)
#           # => SalaryPolicy#update?

#           authorize Employee.find(2), :update?                          < find(2)
#           # => EmployeePolicy#update?

#           authorize LeaveRequest.find(3), :update?                          < find(3)
#           # => LeaveRequestPolicy#update?

#  2. Luồng ánh xạ
#  Chọn Model để xem Pundit ánh xạ

#           Salary                                  #  Employee                                     #  LeaveRequest
#  authorize Salary, :update?                 authorize Employee, :update?                authorize LeaveRequest, :update?
#         v                                              v                                                v
#      SalaryPolicy                                 EmployeePolicy                                 LeaveRequestPolicy
#  Pundit chọn Policy theo Model              Pundit chọn Policy theo Model                   Pundit chọn Policy theo Model
#         v                                              v                                                 v
#       update?                                       update?                                            update?
#  allowed?("salary.update")                    allowed?("employee.update")                       allowed?("leave_request.update")

#  3. Nếu Controller thuộc Module Salary nhưng truyền Model Employee?
#  Ví dụ:
#       class SalariesController < ApplicationController
#         def update_employee
#           employee = Employee.find(params[:id])

#           authorize employee, :update?
#         end
#       end
#  Pundit sẽ gọi:
#         EmployeePolicy#update?
#  Không phải SalaryPolicy#update?, dù lệnh được gọi bên trong SalariesController.                  <
#  Vì Pundit dựa vào đối tượng employee, tức Model Employee.                                    <

#  4. So sánh với Laravel
#  Laravel cũng có nguyên tắc tương tự:
#  // Salary
#  $this->authorize('update', $salary);
#  // => SalaryPolicy::update($user, $salary)

#  // Employee
#  $this->authorize('update', $employee);
#  // => EmployeePolicy::update($user, $employee)

#  // LeaveRequest
#  $this->authorize('update', $leaveRequest);
#  // => LeaveRequestPolicy::update($user, $leaveRequest)


#  Thành phần	                      Rails Pundit	                    Laravel
#  Xác định Policy	          Dựa vào Model truyền vào	          Dựa vào Model và Policy mapping                             <
#  Tên phương thức	                  update?	                          update()
#  User	                        Truyền vào constructor             Policy	Truyền vào phương thức Policy
#  Bản ghi	                      record trong Policy               	$salary, $employee...
