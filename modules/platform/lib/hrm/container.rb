module Hrm # Đây là Namespace. Tương đương PHP: namespace Hrm; class Container { }  | Nó giúp phân biệt Hrm::Container với các class Container khác trong ứng dụng.
  # Small, explicit binding registry. Store names, not reloadable class instances.
  class Container
    # B. Hai Exception tùy chỉnh
    class MissingBinding < StandardError; end # MissingBinding  | Chưa đăng ký Contract vào Container
    class InvalidBinding < StandardError; end # InvalidBinding  | Implementation tạo ra không thuộc kiểu Contract yêu cầu
    # Ví dụ: Hrm::Container.resolve(SalaryRepositoryInterface)  | Nếu chưa đăng ký, Container sẽ báo lỗi MissingBinding.
    def initialize #  Constructor là phương thức initialize, tương đương __construct() trong PHP.
      # Có hai thành phần:
      @bindings = {} # @bindings = {} là Hash lưu danh sách ánh xạ. | Ví dụ nội dung: {   "SalaryRepositoryInterface" => "SalaryRepository",  "EmployeeRepositoryInterface" => "EmployeeRepository"xx}
      @mutex = Mutex.new # @mutex = Mutex.new tạo một Mutex để đồng bộ truy cập dữ liệu giữa các Thread. |  Khi nhiều request hoặc Thread cùng đăng ký binding, Mutex giúp tránh việc sửa Hash đồng thời không được kiểm soát.
    end
    def bind(contract, implementation:) # Đây là phương thức đăng ký Dependency. | Ví dụ: Hrm::Container.bind( SalaryRepositoryInterface, implementation: SalaryRepository )
      # Hai dòng:
      key = contract.is_a?(String) ? contract : contract.name # Chuyển Contract và Implementation thành tên String.
      target = implementation.is_a?(String) ? implementation : implementation.name # Chuyển Contract và Implementation thành tên String.
      # Kết quả lưu: { "SalaryRepositoryInterface" => "SalaryRepository" }  | Lưu ý: Container lưu tên class, không lưu đối tượng đã được khởi tạo.
      @mutex.synchronize { @bindings[key] = target }
    end
    def resolve(contract) # resolve — phần quan trọng nhất   |  Giả sử bạn gọi: repository = Hrm::Container.resolve(SalaryRepositoryInterface)    chú thích bên dưới ( v )
      key = contract.is_a?(String) ? contract : contract.name # resolve(SalaryRepositoryInterface)      Yêu cầu một Repository
      target = @mutex.synchronize { @bindings.fetch(key) { raise MissingBinding, "No provider registered for #{key}" } } # @bindings.fetch(key)    Tìm tên Implementation đã đăng ký
      instance = target.constantize.new # target.constantize.new         Chuyển tên String thành Class và tạo Object
      raise InvalidBinding, "#{target} must implement #{key}" unless instance.is_a?(key.constantize) # instance.is_a?(key.constantize)    Kiểm tra Object có đúng Contract không
      instance
    end # Hợp lệ : Trả về instance  |  Không hợp lệ : InvalidBinding
    # Giải thích hai cú pháp dễ nhầm: target.constantize.new
    # constantize: ActiveSupport - chuyển tên String thành Class. - new: Tạo instance của Class đó.  |  Ví dụ: "SalaryRepository".constantize.new - Tương đương ý tưởng PHP: $class = SalaryRepository::class;$instance = new $class();
    # instance.is_a?(key.constantize) - Kiểm tra instance có thuộc Class/Module Contract đó hay không. - Ruby không có interface theo cú pháp PHP. Bạn có thể dùng Module làm Contract và để Implementation include Module đó.
    def bindings = @mutex.synchronize { @bindings.dup.freeze } # Phương thức này trả về bản sao của Hash binding, rồi freeze để không thể sửa trực tiếp bản sao đó.
    class << self # class << self định nghĩa các Class Methods. | Nhờ đó bạn gọi trực tiếp:
      # Hrm::Container.bind(...) Hrm::Container.resolve(...)
      # Thay vì phải tự tạo: container = Hrm::Container.new container.bind(...) container.resolve(...)
      def default = @default ||= new # default sử dụng @default ||= new để tái sử dụng một Container mặc định sau khi được tạo. Tuy nhiên, cách khởi tạo này chưa được bảo vệ bằng Mutex, nên không nên mặc nhiên xem nó là khởi tạo singleton an toàn tuyệt đối giữa các Thread.
      def bind(contract, implementation:) = default.bind(contract, implementation: implementation)
      delegate :resolve, to: :default
      delegate :bindings, to: :default
    end
  end
end
# Đoạn code này đang tự xây dựng một Dependency Injection Container (DI Container) cho Ruby on Rails, nằm trong module Hrm.
# Nó tương đương với cơ chế Service Container + Interface Binding mà bạn đã học trong Laravel.

# resolve — phần quan trọng nhất
#       def resolve(contract) # resolve — phần quan trọng nhất   |  Giả sử bạn gọi: repository = Hrm::Container.resolve(SalaryRepositoryInterface)    chú thích bên dưới ( v )
#          key = contract.is_a?(String) ? contract : contract.name
#          target = @mutex.synchronize { @bindings.fetch(key) { raise MissingBinding, "No provider registered for #{key}" } }
#          instance = target.constantize.new
#          raise InvalidBinding, "#{target} must implement #{key}" unless instance.is_a?(key.constantize)
#          instance
#        end
# Giả sử bạn gọi:
#         repository = Hrm::Container.resolve(SalaryRepositoryInterface)


# Quy trình:
#     resolve(SalaryRepositoryInterface)
#     Yêu cầu một Repository
#               v
#     @bindings.fetch(key)
#     Tìm tên Implementation đã đăng ký
#               v
#     target.constantize.new
#     Chuyển tên String thành Class và tạo Object
#               v
#     instance.is_a?(key.constantize)
#     Kiểm tra Object có đúng Contract không
#           v                       v
#         Hợp lệ                Không hợp lệ
#     Trả về instance           InvalidBinding




# Giải thích hai cú pháp dễ nhầm:
# target.constantize.new


# - constantize: ActiveSupport chuyển tên String thành Class.
# - new: Tạo instance của Class đó.
# Ví dụ:
#     "SalaryRepository".constantize.new
# Tương đương ý tưởng PHP:
# $class = SalaryRepository::class;
# $instance = new $class();
# Còn:
# instance.is_a?(key.constantize)
#     Kiểm tra instance có thuộc Class/Module Contract đó hay không.
#     Ruby không có interface theo cú pháp PHP. Bạn có thể dùng Module làm Contract và để Implementation include Module đó.


#  So sánh Ruby và Laravel                                    <
#  Chức năng                    	Ruby Container	                    Laravel Container
#  Đăng ký	                  bind(contract, implementation:)	      $app->bind(Contract::class, Impl::class)
#  Giải quyết dependency	    resolve(Contract)	                      app(Contract::class)
#  Tạo Object	                    constantize.new	                       Reflection / Container resolution
#  Kiểm tra Contract            	is_a?	                                Type system / interface
#  Lifetime                 	Instance mới mỗi lần resolve        	bind tạo mới, singleton tái sử dụng
#  Constructor Injection        	Chưa tự động hỗ trợ	                      Có hỗ trợ

# So sánh kiến trúc                                         <
# Thành phần	                          Ruby on Rails (code của bạn)              	Laravel
# Namespace                                   	module Hrm	                  namespace Modules\Hrm
# DI Container	                            Hrm::Container tự viết          	Illuminate\Container\Container
# Provider	                                Tự tổ chức nơi đăng ký                	ServiceProvider
# Đăng ký dependency	                            bind()                          	$this->app->bind()                      <
# Lấy dependency	                              resolve()	                            app()
# Constructor Injection tự động	       Container hiện tại chưa hỗ trợ	                  Có
# Singleton	                          Chưa hỗ trợ cho instance dependency	     $this->app->singleton()                      <

# là module Hrm đang là nghiệp vụ tạo sevice container cho provider còn laravel thì đã có famework hỗ trợ ?               <
# Đúng rồi, bạn hiểu đúng bản chất. Tuy nhiên, cần phân biệt module Hrm, Container và Provider.
#     module Hrm: Namespace chứa các thành phần của hệ thống HRM, không phải bản thân Service Container.
#     Hrm::Container: DI Container do lập trình viên tự xây dựng để quản lý Contract → Implementation.
#     Provider: Nơi đăng ký các binding vào Container.
# 1. Ruby on Rails — tự xây dựng Container                              <
#           module Hrm
#             class Container
#               def initialize
#                 @bindings = {}
#               end
#               def bind(contract, implementation:)
#                 @bindings[contract] = implementation
#               end
#               def resolve(contract)
#                 @bindings.fetch(contract).new
#               end
#             end
#           end
# Đăng ký:
#            Hrm::Container.bind(
#              SalaryRepositoryInterface,
#              implementation: SalaryRepository#
#           )
# Sử dụng:
#            repository = Hrm::Container.resolve(
#              SalaryRepositoryInterface#
#           )
# Lưu ý: Ví dụ trên minh họa cơ chế; phương thức bind và resolve cấp class được định nghĩa trong code Container đầy đủ mà bạn gửi trước đó.

# 2. Laravel — Framework đã hỗ trợ Service Container                      <
# Bạn không cần tự viết Container.
# Trong AppServiceProvider:
#           use Illuminate\Support\ServiceProvider;
#           class AppServiceProvider extends ServiceProvider#
#           {
#               public function register(): void
#               {
#                   $this->app->bind(
#                       SalaryRepositoryInterface::class,
#                       SalaryRepository::class
#                   );
#               }#
#           }
# Sau đó Laravel có thể tự động Dependency Injection:
#           class SalaryService
#           {
#               public function __construct(
#                   private SalaryRepositoryInterface $repository
#               ) {}
#           }
# Laravel tự tìm SalaryRepository đã đăng ký và inject vào SalaryService khi Service được Container khởi tạo.
