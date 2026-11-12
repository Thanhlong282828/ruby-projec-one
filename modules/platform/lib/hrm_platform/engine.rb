module HrmPlatform
  class Engine < ::Rails::Engine # Engine: Class do dự án định nghĩa. | <: Kế thừa. | ::Rails::Engine: Class Engine của Rails ở namespace gốc.| - ::Rails::Engine: Class Engine của Rails ở namespace gốc. | Rails Engine cho phép đóng gói một phần ứng dụng, chẳng hạn HRM, CRM hoặc Payroll, với routes, controllers, models, migrations và cấu hình riêng. | Trong Laravel, nó gần với cơ chế module kết hợp Service Provider.
    engine_name "hrm_platform" # Đặt tên định danh cho Engine là hrm_platform. | Tên này phục vụ cơ chế nhận diện Engine của Rails, không phải tên bảng database hay permission.
    config.root = File.expand_path("../..", __dir__) # Xác định thư mục gốc của Engine. | Trong Ruby: - __dir__: Thư mục chứa file hiện tại. - "../..": Đi lên hai cấp thư mục. - File.expand_path: Chuyển đường dẫn thành đường dẫn tuyệt đối.
    # Ví dụ nếu file nằm ở: engines/hrm_platform/lib/hrm_platform/engine.rb | Thì đường dẫn được tính sẽ là: engines/hrm_platform/lib | Vì vậy, cần kiểm tra vị trí thực tế của file. ../.. không mặc nhiên luôn trỏ đến thư mục gốc của Engine.
    config.after_initialize do |app| # config.after_initialize — chạy sau khi khởi tạo
      # MigrationContext also runs outside Rake (pending checks, console, deploys).
      ActiveRecord::Migrator.migrations_paths = app.config.paths["db/migrate"].expanded # ^
    end # | after_initialize là callback chạy sau khi Rails hoàn thành quá trình khởi tạo ứng dụng. | Ở đây nó thiết lập danh sách đường dẫn Migration mà ActiveRecord sử dụng. | Mục đích là giúp các cơ chế kiểm tra hoặc chạy migration sử dụng đúng danh sách migration paths đã cấu hình. | Lưu ý: Dòng này chỉ thiết lập đường dẫn. Nó không tự chạy db:migrate.

    # Like Laravel's provider registration; re-run after Rails reloads classes.
    config.to_prepare do # config.to_prepare — đăng ký Service Provider # Tại sao dùng to_prepare thay vì chỉ gọi một lần? | Trong môi trường Development, Rails có thể reload các Class khi code thay đổi. | config.to_prepare cho phép đăng ký lại binding trong các chu kỳ chuẩn bị/reload. | Điều này phù hợp với Container của bạn vì nó lưu tên Class dưới dạng String, thay vì giữ instance của Class có thể bị Rails reload. | to_prepare có thể chạy nhiều lần, nên thao tác register() cần an toàn khi thực hiện lặp lại. Binding hiện tại ghi đè theo cùng key, nên tương đối phù hợp.
      HrmPlatform::Providers::PlatformServiceProvider.new.register # | Nó có nghĩa là:Khi Rails chuẩn bị các class của ứng dụng, hãy khởi tạo PlatformServiceProvider và gọi register().
    end
    #     Bạn đã có:                                                            Như vậy, toàn bộ luồng là:   Rails khởi tạo Engine  >     config.to_prepare                     >     PlatformServiceProvider         >  Hrm::Container               > OutboxDispatchJob
    #               class PlatformServiceProvider < Hrm::ServiceProvider                                       HrmPlatform::Engine    Gọi PlatformServiceProvider.new.register     Đăng ký Contract → Implementation     Lưu binding trong @bindings    Gọi resolve để lấy Repository khi cần
    #                 def register
    #                   bind(
    #                     "HrmPlatform::Domain::Repositories::OutboxRepositoryInterface",
    #                     "HrmPlatform::Infrastructure::Persistence::ActiveRecordOutboxRepository"
    #                   )
    #                 end
    #               end

    # Shared schema and public constants preserve existing data and route helpers.
    # Code is owned by an engine, while the host composes the enabled modules.
    # Hai dòng này giúp Rails tìm và tải code trong thư mục lib của Engine.
    #             Cấu hình                                          Chức năng
    config.autoload_paths << root.join("lib") # Cho phép Rails tự tải các Class/Module khi được tham chiếu
    config.eager_load_paths << root.join("lib") # Đưa đường dẫn vào danh sách tải trước khi eager loading được bật
    # Ví dụ bạn gọi: HrmPlatform::Providers::PlatformServiceProvider | Rails có thể tìm Class theo quy ước đặt tên file và namespace. | Lưu ý: Các đường dẫn và tên file phải phù hợp với quy ước autoload của Zeitwerk; chỉ thêm đường dẫn không bảo đảm mọi cấu trúc file đều được tải đúng.
    # Ba initializer có nhiệm vụ gì?
    # A. Đăng ký Routes | Thêm thư mục config/routes của Engine vào danh sách đường dẫn dùng để nạp định nghĩa routes. | Nó không trực tiếp tạo một URL cụ thể. Routes thực tế còn phụ thuộc các file route và cách host application nạp chúng.
    initializer "hrm_platform.route_fragments" do |app|
      app.routes.draw_paths << root.join("config/routes").to_s
    end
    # B. Đăng ký lịch chạy | Dòng này đăng ký đường dẫn file lịch chạy vào cấu hình HRM. |  Ví dụ: config/schedule.yml | Có thể chứa lịch chạy Outbox Job hoặc các tác vụ định kỳ khác. | Quan trọng: Đăng ký file schedule không đồng nghĩa với việc Job đã được scheduler thực thi. Phải có thành phần khác đọc file này và đăng ký lịch chạy thực tế.
    initializer "hrm_platform.schedules" do |app|
      app.config.x.hrm.schedule_files ||= []
      app.config.x.hrm.schedule_files << root.join("config/schedule.yml")
    end
    # C. Đăng ký Migration | Thêm đường dẫn migration của Engine vào danh sách migration paths của ứng dụng chính. | Nhờ đó, ứng dụng có thể nhận diện migration thuộc module HRM.
    initializer "hrm_platform.migrations" do |app|
      app.config.paths["db/migrate"].concat(config.paths["db/migrate"].expanded)
    end
  end
end
# Đoạn code này là Rails Engine của module HrmPlatform. Đây là thành phần giúp Rails nhận diện, khởi tạo và tích hợp module HRM vào ứng dụng chính.
# Nếu so sánh với Laravel Modular Architecture (nwidart/laravel-modules), thì HrmPlatform::Engine gần giống Module Bootstrap + Service Provider + đăng ký Routes, Migrations và cấu hình module.
# Điểm quan trọng: Engine không phải Service Container và cũng không trực tiếp thực hiện nghiệp vụ. Nó chịu trách nhiệm khởi tạo và kết nối các thành phần của module với Rails

# So sánh Rails Engine và Laravel Module                                        < quan trọng
#   Rails HRM                           	Laravel Modular
# HrmPlatform::Engine	                 Bootstrap của module + Service Providers
# config.to_prepare               	  Cơ chế khởi tạo/đăng ký Provider
# PlatformServiceProvider#register	  ServiceProvider::register()
# Hrm::Container	                    Laravel Service Container
# autoload_paths                    	Composer PSR-4 autoload
# routes.draw_paths                 	Đăng ký route files
# migrations_paths	                  loadMigrationsFrom()
# schedule_files	                    Cấu hình schedule riêng của module

# Một điểm cần chú ý trong kiến trúc của bạn                                        < quan trọng
# Trong đoạn code này, Engine đang đảm nhiệm Composition Root ở mức module: kết nối Provider, đường dẫn code, routes, schedules và migrations vào ứng dụng Rails.

# Tuy nhiên, nó không trực tiếp kiểm tra permission, xử lý Outbox hoặc gửi Realtime.

# Những trách nhiệm đó nằm ở:
#       - UseCase / Policy: Kiểm tra quyền và thực hiện nghiệp vụ.
#       - OutboxRepository: Lưu và xử lý trạng thái Outbox.
#       - OutboxDispatchJob: Điều phối gửi sự kiện.
#       - ActionCable: Phát dữ liệu Realtime.


# Chốt lại: HrmPlatform::Engine là bộ phận tích hợp module HRM vào Rails.                                       < quan trọng
#  Nó gần giống việc kết hợp Module Bootstrap + Service Provider registration + Routes + Migrations + Schedule configuration trong Laravel.                                       < quan trọng
#   Đây cũng là đoạn code giải thích vì sao PlatformServiceProvider của bạn được gọi tự động khi Rails khởi tạo hoặc chuẩn bị lại ứng dụng.                                       < quan trọng
