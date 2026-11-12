module HrmWorkforce
  module Application
    module Queries
      class ListDepartments < Hrm::UseCase # ListDepartments kế thừa Hrm::UseCase. | Hrm::UseCase sẽ kiểm tra actor có được phép truy cập, sau đó gọi Pundit.
        # Trong Hrm::UseCase bạn đã học có phương thức:
        # def authorize!(actor, record, query)
        #   require_actor!(actor)
        #   Pundit.authorize(actor, record, query)
        # end
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface)) # initialize — Constructor và Dependency Injection
          super()
          @repository = repository

          # Đây là phần quan trọng nhất về DI.
          # Phân tích:
          #       Thành phần                        	Chức năng
          #       initialize                        Constructor Ruby
          #       repository:                       Keyword argument
          #       Hrm::Container.resolve(...)     	Yêu cầu Container cung cấp Repository
          #       ReadRepositoryInterface         	Contract mà Query phụ thuộc
          #       @repository                       Instance variable lưu Repository
          # Khi Controller gọi:
          #      HrmWorkforce::Application::Queries::ListDepartments.new
          # Ruby sẽ sử dụng giá trị mặc định của repository: và gọi:
          #       Hrm::Container.resolve(
          #         HrmWorkforce::Domain::Repositories::ReadRepositoryInterface
          #       )
          # Container tìm Implementation đã được đăng ký và tạo đối tượng tương ứng.
          # Ví dụ minh họa, nếu Provider đã đăng ký:
          #       bind(
          #         "HrmWorkforce::Domain::Repositories::ReadRepositoryInterface",
          #         "HrmWorkforce::Infrastructure::Persistence::ActiveRecordReadRepository"
          #       )
          # thì Container sẽ trả về instance của ActiveRecordReadRepository.
          # Tên Implementation trên chỉ là ví dụ; bạn chưa cung cấp Provider của HrmWorkforce nên chưa thể xác nhận tên class thực tế.
          # Một điểm đáng chú ý: bạn cũng có thể tự truyền Repository khi khởi tạo:    <  có thể làm giả
          #         ListDepartments.new(repository: fake_repository)
          # Điều này rất hữu ích khi viết Unit Test, vì không cần kết nối Database thật.
        end
        # Phương thức nhận hai keyword arguments:
        def call(actor:, page: 1) # actor: bắt buộc — người dùng đang thực hiện hành động.| page: 1 tùy chọn — mặc định trang 1.
          # |  Ví dụ: query.call(actor: current_user, page: 2)
          # Bước 1 — Kiểm tra quyền
          authorize!(actor, ::Department, :index?) # actor: Người dùng hiện tại. | ::Department: Model Department ở namespace gốc. | :index?: Tên phương thức Policy cần kiểm tra.
          # Hrm::UseCase sẽ kiểm tra actor có được phép truy cập, sau đó gọi Pundit.  | Theo quy ước: ::Department > DepartmentPolicy > index?
          # Ví dụ Policy:
          #  class DepartmentPolicy < ApplicationPolicy
          #    def index?
          #      allowed?("department.view")
          #    end
          #  end
          #     Đây là ví dụ minh họa. Permission string thực tế phải xem trong DepartmentPolicy của project. |
          # Bước 2 — Gọi Repository
          @repository.departments(actor: actor, page: page)
          # Repository có thể thực hiện truy vấn tương tự:
          # def departments(actor:, page:)
          #   ::Department
          #     .where(company_id: actor.company_id)
          #     .order(:id)
          #     .limit(25)
          #     .offset(([page.to_i, 1].max - 1) * 25)
          # end
          # Bước 3 — Trả dữ liệu
          # Ruby tự động trả về kết quả của biểu thức cuối cùng.
          # Vì vậy:
          #     def call(actor:, page: 1)
          #       authorize!(actor, ::Department, :index?)
          #       @repository.departments(actor: actor, page: page)
          #     end
          # tương đương về ý nghĩa với:
          #     def call(actor:, page: 1)
          #       authorize!(actor, ::Department, :index?)
          #       return @repository.departments(
          #         actor: actor,
          #         page: page
          #       )
          #     end
          # Không cần viết return tường minh.
        end
      end
    end
  end
end
# Đây chính là Query xử lý nghiệp vụ lấy danh sách phòng ban trong kiến trúc CQRS của project Ruby on Rails HRM.
# Điểm quan trọng nhất của đoạn code này là:
#         Controller → Query → Authorization → Repository → Database
# Nó cũng cho thấy Hrm::Container, Hrm::UseCase và ReadRepositoryInterface mà bạn học trước đó đang phối hợp với nhau như thế nào.

# 3. Kết nối với DepartmentsController trước đó
# GET /api/v1/departments?page=2
# HTTP Request
#       v
# DepartmentsController#index
# ListDepartments.new.call(...)
#       v
# Hrm::Container.resolve
# Lấy Implementation của ReadRepositoryInterface
#       v
# ListDepartments#call
# authorize! → DepartmentPolicy#index?
#       v
# @repository.departments
# Lấy danh sách theo actor và page
#       v
# Controller render JSON
# Trả { data: records } về Client

# 4. So sánh với Laravel CQRS
# Ruby on Rails
#       class ListDepartments < Hrm::UseCase
#         def initialize(repository: Hrm::Container.resolve(
#           Domain::Repositories::ReadRepositoryInterface
#         ))
#           @repository = repository
#         end
#
#         def call(actor:, page: 1)
#           authorize!(actor, ::Department, :index?)
#           @repository.departments(actor: actor, page: page)
#         end
#       end
# Laravel PHP
#       class ListDepartments
#       {
#           public function __construct(
#               private ReadRepositoryInterface $repository
#           ) {}
#
#           public function handle(User $actor, int $page = 1)
#           {
#               Gate::forUser($actor)->authorize('viewAny', Department::class);
#
#               return $this->repository->departments($actor, $page);
#           }
#       }
# Trong Laravel, Service Container có thể tự inject Repository vào constructor nếu Interface đã được bind.
# Còn trong code Ruby của bạn, Hrm::Container.resolve(...) được gọi tường minh trong giá trị mặc định của constructor.
