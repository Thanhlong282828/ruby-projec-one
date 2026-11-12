module HrmPlatform
  module Providers
    class PlatformServiceProvider < Hrm::ServiceProvider # A. class PlatformServiceProvider < Hrm::ServiceProvider Dấu < là kế thừa. PlatformServiceProvider kế thừa từ Hrm::ServiceProvider, nên sử dụng được phương thức bind đã khai báo protected trong class cha.
      def register # B. def register | Đây là phương thức ghi đè register của class cha.
        #        Trong class cha:      def register = raise(NotImplementedError)
        #        Trong class con:      def register bind(...) end
        bind "HrmPlatform::Domain::Repositories::OutboxRepositoryInterface", "HrmPlatform::Infrastructure::Persistence::ActiveRecordOutboxRepository" # < Nghĩa là:
        # Khi hệ thống yêu cầu OutboxRepositoryInterface, hãy sử dụng ActiveRecordOutboxRepository.
        # Hai tham số đang là String chứa tên class đầy đủ, không phải object.
      end
    end
  end
end

# Đây chính là Service Provider thực tế của module HrmPlatform, có nhiệm vụ đăng ký OutboxRepositoryInterface với ActiveRecordOutboxRepository vào DI Container mà bạn đã xây dựng trước đó.

# Nó tương đương với register() trong Laravel Service Provider.

# Luồng hoạt động thực tế
#     PlatformServiceProvider.new.register
#     Khởi tạo Provider và gọi register
#             v
#     Hrm::ServiceProvider#bind
#     Phương thức protected được kế thừa
#             v
#     Hrm::Container.bind
#     Lưu Contract → Implementation
#             v
#     Hrm::Container.resolve
#     Tạo instance của ActiveRecordOutboxRepository

# Khi register chạy, Container sẽ lưu ánh xạ:
#             {
#               "HrmPlatform::Domain::Repositories::OutboxRepositoryInterface" =>
#               "HrmPlatform::Infrastructure::Persistence::ActiveRecordOutboxRepository"
#             }
# Lưu ý: Đăng ký binding chưa tạo Repository. Repository chỉ được tạo khi gọi resolve.

# 3. Khi OutboxDispatchJob yêu cầu Repository
#             repository = Hrm::Container.resolve(
#               "HrmPlatform::Domain::Repositories::OutboxRepositoryInterface"
#             )
#
#
# Container thực hiện:
#             # 1. Tìm Implementation
#             target = "HrmPlatform::Infrastructure::Persistence::ActiveRecordOutboxRepository"
#
#             # 2. Chuyển String thành Class và tạo Object                                        < quan trọng
#             instance = target.constantize.new
#
#             # 3. Kiểm tra kế thừa Contract
#             instance.is_a?(
#               HrmPlatform::Domain::Repositories::OutboxRepositoryInterface
#             )
#             # => true
#
#
# Sau đó Job có thể sử dụng:
#             repository.pending(limit: 100)
#
#
# Hoặc:
#             repository.append!(
#               company_id: 10,
#               event_type: "salary.updated",
#               payload: { salary_id: 100 }
#             )
#
#
# 4. So sánh với Laravel
# Ruby on Rails                                               Laravel
# class PlatformServiceProvider < Hrm::ServiceProvider        class PlatformServiceProvider extends ServiceProvider
#   def register                                              {
#     bind(                                                       public function register(): void
#       "OutboxRepositoryInterface",                              {
#       "ActiveRecordOutboxRepository"                                $this->app->bind(
#     )                                                                   OutboxRepositoryInterface::class,
#   end                                                                   ActiveRecordOutboxRepository::class
# end                                                                 );
#                                                                 }
#                                                             }
# Ví dụ rút gọn tên class; trong dự án thực tế sử dụng namespace đầy đủ.Khác biệt quan trọng là Laravel có Service Container tích hợp và tự bootstrap các Provider đã đăng ký. Còn trong code Rails này, bạn phải có nơi gọi:
#             HrmPlatform::Providers::PlatformServiceProvider.new.register
# Nếu chưa gọi register, Container sẽ chưa có binding và resolve sẽ phát sinh MissingBinding.
