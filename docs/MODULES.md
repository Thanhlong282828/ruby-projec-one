# Module (thư viện) + MVC

## Cách lắp ghép

Gemfile khai báo 9 local gems `hrm_platform`, `hrm_identity`, `hrm_workforce`, `hrm_attendance`, `hrm_time_off`, `hrm_payroll`, `hrm_recruitment`, `hrm_audit`, `hrm_dashboard` từ thư mục modules. Mỗi gem có gemspec, entrypoint và Rails::Engine. Rails tự nạp models/controllers/views/policies/services/jobs/assets/initializers/tasks của engine; không dùng require thủ công từng class.

Routing nằm trong module, host dùng `draw` để ghép cùng route set nên URL, helper và API v1 không đổi. Platform sở hữu ApplicationRecord, ApplicationController, API BaseController, ApplicationPolicy và UI shell. Domain service giữ transaction, controller chỉ điều phối; model giữ association/validation; policy quyết định quyền; view trình bày.

## Quy tắc phát triển

1. Xác định module sở hữu tính năng, thêm mã trong module đó, không đưa lại controller/model nghiệp vụ lên host.
2. Controller không chứa phép tính bảng lương hoặc xử lý phê duyệt; đặt service trong namespace nghiệp vụ.
3. Không sao chép base classes giữa module. Chức năng hạ tầng dùng chung thuộc platform; tránh chuyển mọi logic vào shared.
4. API của một domain đặt cùng module với MVC web của domain đó.
5. Test domain đặt cạnh module; hành trình nhiều domain giữ ở test/integration. `rails test` nạp module tests qua test/modules_test.rb.
6. Migration mới nằm trong modules/<module>/db/migrate, timestamp unique toàn hệ thống. Engine tự thêm đường dẫn migration vào host. Baseline db/migrate/20261025000001_create_hrm.rb giữ nguyên vì đã áp dụng; schema.rb tiếp tục là ảnh chụp chung do Rails sinh.
7. Lịch chạy thuộc module trong config/schedule.yml (Platform: outbox; TimeOff: tổng hợp). Engine đăng ký file lịch, Sidekiq của Platform nạp các lịch khi khởi động.
8. Việc tạo local gem mới cần thêm Gemfile, route fragment, README sở hữu/phụ thuộc và kiểm thử. Docker COPY modules trước bundle install để Bundler đọc gemspec.

## Giới hạn ranh giới

Đây là các non-isolated Rails Engines trong modular monolith: model constants hiện hữu (Employee, User, PayRun...) và bảng giữ nguyên, host ghép các route. Không tạo bản sao model hoặc alias che giấu định nghĩa. Namespace đóng gói engine là HrmWorkforce, HrmTimeOff...; controller/service nghiệp vụ vẫn giữ namespace Workforce, TimeOff, Payroll, Recruitment.

Module giao tiếp qua association, policy và service đã có; chúng chưa có database riêng hoặc ràng buộc dependency tĩnh hoàn toàn. Gem platform có tích hợp phát sự kiện dùng Audit; Identity liên kết Employee của Workforce. Vì thế không thể gỡ tùy ý một module rồi kỳ vọng toàn bộ host vẫn chạy. Tách độc lập sâu hơn cần thay các liên kết này bằng public contract và thay đổi tên model có migration tương thích; không thuộc lần sắp xếp này.

Cơ sở triển khai Rails Engine: https://guides.rubyonrails.org/engines.html

## Quét bảo mật

Dùng `bundle exec ruby bin/brakeman --no-pager`: wrapper tự thu thập modules có app/ và truyền --add-engines-path cho Brakeman. CI dùng cùng lệnh để quét đủ MVC của tất cả module.
