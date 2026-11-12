Gem::Specification.new do |spec| # A.| Gem::Specification là class thuộc RubyGems. | .new tạo một đối tượng Specification, còn do |spec| ... end là Block để cấu hình đối tượng đó. | Tương tự về ý tưởng với việc khai báo metadata trong composer.json của PHP.
  spec.name = "hrm_platform"
  spec.version = "0.1.0"
  spec.authors = [ "XinViec" ]
  spec.summary = "XinViec HRM platform module"
  spec.required_ruby_version = ">= 3.4" # B.| Nghĩa là Gem yêu cầu Ruby từ phiên bản 3.4 trở lên. | Đây cũng là lý do Ruby 3.3.6 bạn cài trước đó không đáp ứng yêu cầu. | Tuy nhiên, Gemfile.lock của ứng dụng bạn đang khóa Ruby 3.4.12, nên khi khôi phục môi trường nên dùng Ruby 3.4.12.
  spec.files = Dir.chdir(__dir__) { Dir.glob("{app,config,db,lib,test}/**/*").select { |file| File.file?(file) } } # C. spec.files — lấy danh sách file của Gem
  # Phân tích:| __dir__: Thư mục chứa file .gemspec. | Dir.chdir(__dir__): Tạm chuyển thư mục làm việc khi chạy Block. | Dir.glob(...): Tìm các file theo pattern. | {app,config,db,lib,test}: Tìm trong năm thư mục này. | **/*: Tìm đệ quy các file và thư mục con. | .select: Lọc kết quả. | File.file?(file): Chỉ lấy file, không lấy thư mục.
  # Ví dụ:
  #           hrm_platform/
  #           ├── app/
  #           │   ├── models/
  #           │   └── jobs/
  #           ├── config/
  #           │   ├── routes.rb
  #           │   └── schedule.yml
  #           ├── db/
  #           │   └── migrate/
  #           ├── lib/
  #           │   ├── hrm_platform.rb
  #           │   └── hrm_platform/
  #           │       └── engine.rb
  #           ├── test/
  #           └── hrm_platform.gemspec
  #      Các file phù hợp trong năm thư mục trên sẽ được đưa vào spec.files.
  spec.require_paths = [ "lib" ] # D.| Khi Gem được nạp, RubyGems có thể thêm thư mục lib của Gem vào đường dẫn tìm kiếm. | Vì vậy, câu lệnh bạn vừa học: require "hrm_platform/engine" | có thể tìm tới: lib/hrm_platform/engine.rb | Đây là cơ chế nạp file Ruby, không phải chức năng Cmd + Click của VS Code. Cmd + Click còn phụ thuộc Ruby LSP.
  spec.add_dependency "rails", "~> 8.1.0" # E. spec.add_dependency | Khai báo Gem hrm_platform phụ thuộc Rails:  8.1.0 ≤ Rails version < 8.2.0  | Ví dụ:| Rails 8.1.0: hợp lệ.| Rails 8.1.2: hợp lệ. | Rails 8.2.0: không hợp lệ.
end
# Đây là file hrm_platform.gemspec, dùng để khai báo thông tin, phiên bản, các file và dependency của module HrmPlatform trong Ruby on Rails.
# Nếu so sánh với Laravel, nó gần giống composer.json của một package/module.

# Thuộc tính                        	Chức năng
# Gem::Specification.new	      Tạo cấu hình cho Ruby Gem
# spec.name	                    Tên Gem: hrm_platform
# spec.version	                Phiên bản Gem: 0.1.0
# spec.authors                  	Tác giả package
# spec.summary	                    Mô tả ngắn
# spec.required_ruby_version	    Ruby tối thiểu 3.4
# spec.files	                  Danh sách file được đóng gói
# spec.require_paths	        Thư mục Ruby tìm code khi require
# spec.add_dependency	        Khai báo dependency Rails 8.1.x

# 3. So sánh với Laravel composer.json
# Ruby — Gem Specification
#       spec.name = "hrm_platform"
#       spec.version = "0.1.0"
#       spec.required_ruby_version =
#         ">= 3.4"
#       spec.require_paths = ["lib"]
#       spec.add_dependency(
#         "rails", "~> 8.1.0"
#       )
# PHP — Composer
#       {
#         "name": "xinviec/hrm-platform",
#         "version": "0.1.0",
#         "require": {
#           "php": "^8.3",
#           "laravel/framework": "^12.0"
#         },
#         "autoload": {
#           "psr-4": {
#             "HrmPlatform\\": "src/"
#           }
#         }
#       }
# Ví dụ Composer minh họa cấu trúc tương đương, không phải cấu hình Laravel thực tế của project.

# 4. Liên kết với các file bạn đã gửi
#                       hrm_platform.gemspec
#                              |
#                              | Khai báo Gem và dependency
#                              v
#                       lib/hrm_platform.rb
#                              |
#                              | require "hrm_platform/engine"
#                              v
#                       HrmPlatform::Engine
#                              |
#                              | config.to_prepare
#                              v
#                       PlatformServiceProvider
#                              |
#                              | bind
#                              v
#                       Hrm::Container
#                              |
#                              | resolve
#                              v
#                       ActiveRecordOutboxRepository
#                              |
#                              v
#                       OutboxEvent (Database)
# Lưu ý: Đây là sơ đồ liên hệ các thành phần, không có nghĩa .gemspec trực tiếp thực thi tất cả các bước. Engine phải được nạp và khởi tạo trong ứng dụng Rails.
