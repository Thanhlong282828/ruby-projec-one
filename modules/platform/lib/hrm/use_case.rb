module Hrm # Là Namespace chứa các thành phần nghiệp vụ HRM.
  class UseCase # Đây là lớp cha để các UseCase cụ thể kế thừa. | Ví dụ: class UpdateSalary < Hrm::UseCase end  |  UseCase thường đại diện cho một hành động nghiệp vụ, ví dụ cập nhật lương, duyệt đơn nghỉ phép hoặc tạo nhân viên.
    protected # Hai phương thức bên dưới là protected: require_actor!  authorize!
    def require_actor!(actor) # actor :	Người thực hiện hành động, thường là User |  ! : trong tên phương thức : Quy ước Ruby báo hiệu phương thức cần chú ý, thường có tác động mạnh hoặc có thể gây lỗi
      raise Pundit::NotAuthorizedError unless actor&.enabled_for_access?
      # raise	: Ném Exception | unless :	Nếu điều kiện không đúng thì thực hiện  | &. : Safe Navigation Operator, tránh lỗi khi actor là nil  | enabled_for_access? : Phương thức kiểm tra User có được phép truy cập hệ thống không |
    end
    def authorize!(actor, record, query) # - actor: User thực hiện hành động. - record: Model hoặc bản ghi cần thao tác. - query: Phương thức Policy cần kiểm tra, ví dụ :update?, :create?, :destroy?.
      # Ví dụ:    authorize!(actor, salary, :update?)
      require_actor!(actor) # Kiểm tra actor.enabled_for_access?
      Pundit.authorize(actor, record, query) #  sử dụng Pundit để phân quyền (Authorization) và bảo vệ dữ liệu Multi-Tenant.
      # Pundit.authorize(actor, salary, :update?) :  Tìm SalaryPolicy và gọi update?
    end
  end
end
# Đoạn code này đang xây dựng một Base UseCase trong Ruby on Rails để kiểm tra người thực hiện hành động (Actor) và phân quyền trước khi chạy nghiệp vụ HRM.

# Nó tương đương với việc bạn tạo Base Service hoặc Base Action trong Laravel, kết hợp với Laravel Policy.


# 2. require_actor!(actor) kiểm tra gì?
#  def require_actor!(actor)
#    raise Pundit::NotAuthorizedError unless actor&.enabled_for_access?
#  end
#  Tách từng phần:
#  Cú pháp                          	Ý nghĩa
#  actor                        	Người thực hiện hành động, thường là User
#  &.                           	Safe Navigation Operator, tránh lỗi khi actor là nil
#  enabled_for_access?	          Phương thức kiểm tra User có được phép truy cập hệ thống không
#  unless	                        Nếu điều kiện không đúng thì thực hiện
#  raise	                        Ném Exception
#  ! trong tên phương thức	      Quy ước Ruby báo hiệu phương thức cần chú ý, thường có tác động mạnh hoặc có thể gây lỗi

#  Ví dụ:
#         actor = User.find(10)\
#         require_actor!(actor)
#  Nếu:
#          actor.enabled_for_access? # true
#  Thì tiếp tục.
#  Nếu:
#          actor.enabled_for_access? # false
#  Thì ném:
#          Pundit::NotAuthorizedError
#  Lưu ý: enabled_for_access? là phương thức của User trong dự án, không phải phương thức mặc định của Rails. Muốn biết chính xác nó kiểm tra trạng thái gì, cần xem định nghĩa của nó.




# 3. authorize!(actor, record, query) hoạt động thế nào?            <

#         def authorize!(actor, record, query)                          <
#           require_actor!(actor)
#           Pundit.authorize(actor, record, query)
#         end

#  Có ba tham số:
#  - actor: User thực hiện hành động.
#  - record: Model hoặc bản ghi cần thao tác.
#  - query: Phương thức Policy cần kiểm tra, ví dụ :update?, :create?, :destroy?.
#  Ví dụ:
#        authorize!(actor, salary, :update?)

#  Luồng xử lý:
#                 authorize!(actor, salary, :update?)
#                                 v
#                        require_actor!(actor)
#                  Kiểm tra actor.enabled_for_access?
#          \/                                              x
#        Hợp lệ                                       Không hợp lệ
#           v                                        NotAuthorizedError
#              Pundit.authorize(actor, salary, :update?)
#                   Tìm SalaryPolicy và gọi update?
#                                 v
#                        SalaryPolicy#update?
#                    Kiểm tra Permission + Company
#  Nếu Policy trả về false, Pundit ném Pundit::NotAuthorizedError. Nếu được phép, UseCase có thể tiếp tục xử lý nghiệp vụ.

#  4. Ví dụ UseCase kế thừa                                                         < cái này Ruby ko có Framework hỗ trợ phải tự làm Sevice riêng
#        module Hrm
#          class UpdateSalary < UseCase
#            def call(actor:, salary:, amount:)
#              authorize!(actor, salary, :update?)
#              salary.update!(amount: amount)
#            end
#          end
#        end
#  Sử dụng:
#         Hrm::UpdateSalary.new.call(
#           actor: current_user,
#           salary: Salary.find(100),
#           amount: 20_000_000
#         )
#  Thứ tự:
#         1. Kiểm tra User có được truy cập hệ thống.
#         2. Pundit kiểm tra SalaryPolicy#update?.
#         3. Nếu hợp lệ, cập nhật Salary.
#         4. Nếu không hợp lệ, ném Exception và không chạy dòng cập nhật.


#  5. So sánh với Laravel                                                         < cái này trong Laravel Framework
#  Trong Laravel, bạn có thể tự xây dựng lớp cha tương tự:
#       use Illuminate\Auth\Access\AuthorizationException;
#       use Illuminate\Support\Facades\Gate;
#
#       abstract class UseCase
#       {
#           protected function requireActor(User $actor): void
#           {
#               if (! $actor->enabledForAccess()) {
#                   throw new AuthorizationException();
#               }
#           }
#
#           protected function authorize(
#               User $actor,
#               Model $record,
#               string $ability
#           ): void {
#               $this->requireActor($actor);
#
#               Gate::forUser($actor)->authorize($ability, $record);
#           }
#       }
#
#
#  UseCase con:
#       class UpdateSalary extends UseCase
#       {
#           public function handle(
#               User $actor,
#               Salary $salary,
#               int $amount
#           ): void {
#               $this->authorize($actor, $salary, 'update');
#
#               $salary->update([
#                   'amount' => $amount,
#               ]);
#           }
#       }

# Điểm tương đương:
#      Ruby Rails                              	Laravel
#    Hrm::UseCase                      	Base UseCase / Base Action tự xây dựng
#   require_actor!	                        requireActor()
#    Pundit.authorize	                  Gate::forUser(...)->authorize()                           <<  <<  <
#      :update?                                 	'update'
# Pundit::NotAuthorizedError	              AuthorizationException

# Điểm đáng chú ý: Trong Laravel, dùng Gate::forUser($actor) để kiểm tra đúng User được truyền vào. Nếu chỉ dùng $this->authorize() trong Controller, Laravel thường sử dụng User hiện đang đăng nhập.


# 6. Phân biệt UseCase, ServiceProvider và Policy
# Thành phần	                  Trách nhiệm
# Hrm::Container	        Quản lý Contract → Implementation
# Hrm::ServiceProvider	  Đăng ký dependency
# Hrm::UseCase            Lớp cha cung cấp logic dùng chung cho nghiệp vụ
# SalaryPolicy            Quyết định User có quyền thao tác Salary không
# UpdateSalary            Thực hiện nghiệp vụ cập nhật lương
