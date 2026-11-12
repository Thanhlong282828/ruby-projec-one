module Hrm
  # Equivalent responsibility to a Laravel ServiceProvider#register.
  class ServiceProvider
    def initialize(container: Hrm::Container) # Đây là Constructor, nhận một tham số keyword tên container
      @container = container # container: là tham số keyword. | Hrm::Container là giá trị mặc định. | @container là biến instance lưu Container được truyền vào.
      # Ví dụ:
      #     provider = Hrm::ServiceProvider.new
      # Tương đương:
      #     provider = Hrm::ServiceProvider.new(
      #       container: Hrm::Container
      #     )
      # > Lưu ý: Ở đây truyền Class Hrm::Container, không phải Hrm::Container.new. Điều này hoạt động vì Container trước đó của bạn đã định nghĩa các class method bind và resolve.
    end
    def register = raise(NotImplementedError) # Nghĩa là lớp cha không triển khai logic đăng ký cụ thể. | Lớp con phải ghi đè register, nếu không khi gọi sẽ phát sinh lỗi NotImplementedError. | Tư duy này gần giống Abstract Method trong PHP.
    protected # protected giới hạn việc gọi phương thức bind từ bên ngoài theo quy tắc truy cập của Ruby. | Mục đích là để các Service Provider con dùng bind trong quá trình đăng ký, thay vì xem nó như API công khai.
    def bind(contract, implementation) = @container.bind(contract, implementation: implementation)
    # Ví dụ:
    #       bind(SalaryRepositoryInterface, SalaryRepository)
    # Sẽ gọi tiếp:
    #        @container.bind( SalaryRepositoryInterface,implementation: SalaryRepository )
  end
end
# Đoạn code này đang xây dựng một ServiceProvider cha (Base Service Provider) cho hệ thống HRM trong Ruby on Rails.
# Nó có trách nhiệm tương tự phương thức register() của Laravel Service Provider: đăng ký Contract → Implementation vào DI Container.                <
# Điểm quan trọng: Hrm::ServiceProvider không phải Service Provider có sẵn của Rails. Đây là class do lập trình viên tự xây dựng


#  Mức truy cập	                  Public	                Protected                         	Private
#  Gọi từ bên ngoài Object			    v                           x                                  x
#  Gọi trong chính Class			      v                           v                                  v
#  Class con sử dụng			          v                           v                                  Có thể gọi nội bộ, tùy ngôn ngữ
#  Mục đích	                API công khai     	Logic dùng trong hệ thống kế thừa           	Logic nội bộ


#  2. Ví dụ ServiceProvider con
#  Giả sử có Contract và Implementation:
#            module SalaryRepositoryInterface
#            end
#            class SalaryRepository
#              include SalaryRepositoryInterface
#            end


#  Tạo Provider:
#            module Hrm
#              class SalaryServiceProvider < ServiceProvider
#                def register
#                  bind(
#                    SalaryRepositoryInterface,
#                    SalaryRepository
#                  )
#                end
#              end
#            end


#  Đăng ký:
#            Hrm::SalaryServiceProvider.new.register


#  Sau đó lấy Repository:
#            repository = Hrm::Container.resolve(
#              SalaryRepositoryInterface
#            )


#  Kết quả là một instance của SalaryRepository.                     <
#            SalaryServiceProvider                                     <
#                register()
#                    v
#            ServiceProvider#bind                                     <
#            Contract → Implementation
#                    v
#            Hrm::Container.bind                                     <
#            Lưu ánh xạ vào @bindings
#                    v
#            Hrm::Container.resolve                                     <
#            Tạo SalaryRepository khi được yêu cầu


#  3. So sánh với Laravel
#                    Ruby                                                        Laravel                                                <
#  class SalaryServiceProvider < Hrm::ServiceProvider              class SalaryServiceProvider extends ServiceProvider
#    def register                                                  {
#      bind(                                                           public function register(): void
#        SalaryRepositoryInterface,                                    {
#        SalaryRepository                                                  $this->app->bind(
#      )                                                                       SalaryRepositoryInterface::class,
#    end                                                                       SalaryRepository::class
#  end                                                                     );
#                                                                      }
#                                                                   }
#  Thành phần	                 Ruby	                                     Laravel                                  <
#  Provider cha        	Hrm::ServiceProvider          	      Illuminate\Support\ServiceProvider
#  Constructor	                initialize	                        __construct
#  Đăng ký	                    register                          	register
#  Binding           	bind(contract, implementation)	        $this->app->bind(...)
#  Container	                Tự xây dựng	                        Framework cung cấp
#  Tự chạy Provider	      Cần cơ chế gọi register	            Laravel bootstrap các Provider đã đăng ký               <

#  4. Phân biệt ba thành phần
#  - Container: Lưu và giải quyết dependency.
#  - ServiceProvider: Đăng ký các dependency vào Container.
#  - Service: Chứa logic nghiệp vụ và sử dụng dependency đã được cung cấp.
#  Ví dụ trong HRM:
#                SalaryServiceProvider
#                        |
#                        | register()
#                        v
#                Hrm::Container
#                        |
#                        | bind()
#                        v
#                SalaryRepositoryInterface
#                        |
#                        | resolve()
#                        v
#                SalaryRepository
#                        |
#                        | được sử dụng bởi
#                        v
#                SalaryService


#  Đặc biệt, ServiceProvider của bạn chưa có cơ chế tự động khởi chạy. Phải có đoạn code ở nơi khởi tạo ứng dụng gọi register() cho từng Provider, hoặc một cơ chế bootstrap tương đương.
