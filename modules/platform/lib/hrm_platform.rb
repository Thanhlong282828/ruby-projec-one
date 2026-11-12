  require "hrm_platform/engine"
# Dòng này có nhiệm vụ nạp file engine.rb của module HrmPlatform vào Ruby, để Rails biết đến class HrmPlatform::Engine.

# . Khi file engine.rb được nạp
# Ruby đọc và thực thi phần định nghĩa:
# module HrmPlatform
#   class Engine < ::Rails::Engine
#     config.to_prepare do
#       HrmPlatform::Providers::PlatformServiceProvider.new.register
#     end
#   end
# end


# Từ đó Rails có thể tích hợp Engine và chạy các callback ở giai đoạn khởi tạo thích hợp.
# require "hrm_platform/engine"
#            |
#            v
#    Nạp file engine.rb
#            |
#            v
#    HrmPlatform::Engine
#            |
#            v
#    Rails khởi tạo Engine
#            |
#            v
#       to_prepare
#            |
#            v
#  PlatformServiceProvider
#            |
#            v
#      Hrm::Container
#            |
#            v
#   Đăng ký OutboxRepository

# Ruby	                                        PHP/Laravel
# require "hrm_platform/engine"	        require_once 'engine.php' (gần tương đương)
# Ruby $LOAD_PATH	                          PHP include_path / Composer autoload
# HrmPlatform::Engine                         	Cơ chế bootstrap module
# config.to_prepare	                Callback chuẩn bị ứng dụng, không có tương đương hoàn toàn trong Laravel
