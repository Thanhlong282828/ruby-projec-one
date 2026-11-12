module HrmPlatform # Namespace: HrmPlatform::Domain::Repositories::OutboxRepositoryInterface | Tương đương PHP: namespace HrmPlatform\Domain\Repositories; | Đây là Contract thuộc tầng Domain, không trực tiếp chứa logic database.
  module Domain
    module Repositories
      class OutboxRepositoryInterface                                                                            #   Tham số     ý nghĩa
        def append!(company_id:, event_type:, payload:) # A. append! — Thêm sự kiện | Ba tham số keyword bắt buộc: company_id:	Công ty sở hữu sự kiện | event_type:	Loại sự kiện | payload:	Dữ liệu của sự kiện
          ##  repository.append!( company_id: 10,event_type: "salary.updated",payload: { salary_id: 100,amount: 20_000_000 })
          # Dấu ! trong append! là quy ước Ruby thường dùng cho phương thức có tác động đáng chú ý hoặc có thể phát sinh lỗi; bản thân dấu ! không tự tạo transaction hay exception.
          raise NotImplementedError, "HrmPlatform::OutboxRepositoryInterface##append!" # raise NotImplementedError Nghĩa là: Lớp này chỉ khai báo các phương thức cần có, chưa cung cấp cách thực hiện.
        end
        def pending(limit: 100) # B. pending(limit: 100) — Lấy sự kiện chờ gửi | limit: 100 là keyword argument có giá trị mặc định bằng 100.
          # Ví dụ: repository.pending   Mặc định tối đa 100 sự kiện  |  repository.pending(limit: 25)  Yêu cầu tối đa 25 sự kiện
          ## OutboxEvent.where(delivered_at: nil).order(:id).limit(limit)  < Một Implementation có thể truy vấn  < Đây chỉ là ví dụ triển khai; Interface chưa quy định cách truy vấn, thứ tự hay cơ chế locking.
          raise NotImplementedError, "HrmPlatform::OutboxRepositoryInterface##pending" # raise NotImplementedError Nghĩa là: Lớp này chỉ khai báo các phương thức cần có, chưa cung cấp cách thực hiện.
        end
        def deliver(event:, &block) # C. deliver(event:, &block) — Gửi sự kiện | event: là keyword argument bắt buộc | &block nhận một Block được truyền vào và chuyển nó thành đối tượng Proc.     < Đây là phần quan trọng nhất về cú pháp Ruby.
          ## repository.deliver(event: event) do WebhookClient.send_event(event) end   | Block: do WebhookClient.send_event(event) end - Chứa công việc gửi sự kiện. | Implementation có thể gọi:   block.call - để thực thi nó.
          # Tuy nhiên, Interface hiện tại chưa cho biết deliver sẽ gọi block khi nào, có transaction không, có đánh dấu delivered_at không hoặc có retry không. Muốn xác nhận phải xem Implementation.
          raise NotImplementedError, "HrmPlatform::OutboxRepositoryInterface##deliver" # raise NotImplementedError Nghĩa là: Lớp này chỉ khai báo các phương thức cần có, chưa cung cấp cách thực hiện.
        end
      end #                                                                                      v ví dụ bên dưới
    end
  end
end

# Đoạn code này đang định nghĩa một Repository Interface (Contract) cho nghiệp vụ Transactional Outbox trong hệ thống HRM bằng Ruby.
# Nó tương đương với OutboxRepositoryInterface trong PHP/Laravel, dùng để quy định Repository triển khai phải cung cấp ba chức năng:

# 1. append! — Thêm sự kiện vào Outbox.
# 2. pending — Lấy các sự kiện chưa được đánh dấu đã gửi.
# 3. deliver — Thực hiện quy trình gửi sự kiện.


# 3. Vì sao cả ba đều raise NotImplementedError?                                                <
#          raise NotImplementedError
# Nghĩa là:
#          Lớp này chỉ khai báo các phương thức cần có, chưa cung cấp cách thực hiện.
# Ví dụ Implementation:                                                                               <  ví dụ
#           class ActiveRecordOutboxRepository <
#             HrmPlatform::Domain::Repositories::OutboxRepositoryInterface

#             def append!(company_id:, event_type:, payload:)
#               OutboxEvent.create!(
#                 company_id: company_id,
#                 event_type: event_type,
#                 payload: payload
#               )
#             end

#             def pending(limit: 100)
#               OutboxEvent
#                 .where(delivered_at: nil)
#                 .order(:id)
#                 .limit(limit)
#             end
#             def deliver(event:, &block)
#               block.call
#               event.update!(delivered_at: Time.current)
#             end
#           end
# >> Đây là Implementation minh họa đơn giản, chưa đủ để bảo đảm an toàn khi nhiều Worker cùng gửi hoặc khi gửi thành công nhưng cập nhật database thất bại.

# 4. So sánh Ruby với Laravel
# Ruby                                                           Laravel
#       class OutboxRepositoryInterface                                interface OutboxRepositoryInterface
#         def append!(company_id:, event_type:, payload:)              {
#           raise NotImplementedError                                      public function append(
#         end                                                                  int $companyId,
#                                                                              string $eventType,
#         def pending(limit: 100)                                              array $payload
#           raise NotImplementedError                                      );
#         end                                                          public function pending(
#                                                                             int $limit = 100
#         def deliver(event:, &block)                                     );
#           raise NotImplementedError
#         end                                                             public function deliver(
#         end                                                                 OutboxEvent $event,
#                                                                             callable $callback
#                                                                         );
#                                                                     }
# Có một điểm khác biệt lớn:
#
# PHP Interface được ngôn ngữ kiểm tra khi Class khai báo implements.                             <

#       class OutboxRepository implements OutboxRepositoryInterface
#       {
#           // Phải triển khai các phương thức theo contract
#       }

# Ruby Class ở đây chỉ mô phỏng Interface thông qua kế thừa và NotImplementedError. Ruby không tự bắt buộc lớp con ghi đè tất cả phương thức trước khi khởi tạo.

# 5. Luồng Outbox trong HRM                                           < luồng ví dụ    Sự kiện : Thêm > lấy > Gửi
#             SalaryService
#             Cập nhật lương
#                 v
#             append!
#             Lưu sự kiện salary.updated vào Outbox
#                 v
#             pending
#             Worker lấy sự kiện chưa gửi
#                 v
#             deliver
#             Thực thi block gửi Webhook hoặc Broadcast
#                 v
#             Đánh dấu đã gửi
#             Nếu Implementation hỗ trợ và gửi thành công


# Với Transactional Outbox, việc lưu thay đổi nghiệp vụ và ghi sự kiện Outbox thường phải nằm trong cùng database transaction để tránh tình trạng cập nhật Salary thành công nhưng không lưu được sự kiện.

# 6. Liên hệ với Container trước đó
#     Repository này có thể được đăng ký:
#             Hrm::Container.bind(
#               HrmPlatform::Domain::Repositories::OutboxRepositoryInterface,
#               implementation: ActiveRecordOutboxRepository
#             )

# Sau đó:
#     repository = Hrm::Container.resolve(
#       HrmPlatform::Domain::Repositories::OutboxRepositoryInterface
#     )

# Container của bạn kiểm tra Implementation có kế thừa Contract hay không thông qua is_a?.  | is_a? > Implementation có kế thừa Contract(Hợp đồng)              <

#     1. Phân biệt ba thành phần                                                            < quan trọng
#                                           # 1. Contract (Hợp đồng)
#                                           class OutboxRepositoryInterface
#                                             def pending(limit: 100)
#                                               raise NotImplementedError
#                                             end
#                                           end
#
#                                           # 2. Implementation (Triển khai)
#                                           class OutboxRepository < OutboxRepositoryInterface
#                                             def pending(limit: 100)
#                                               OutboxEvent.limit(limit)
#                                             end
#                                           end
#
#                                           # 3. Container đăng ký ánh xạ
#                                           Hrm::Container.bind(
#                                             OutboxRepositoryInterface,
#                                             implementation: OutboxRepository
#                                           )
#
# Khi gọi:
#             repository = Hrm::Container.resolve(OutboxRepositoryInterface)
# Container thực hiện:
#               instance = OutboxRepository.new
#               instance.is_a?(OutboxRepositoryInterface)
#               # => true
# >> Vì OutboxRepository kế thừa OutboxRepositoryInterface.
#       2. Luồng hoạt động                                                            <
#                                      Hrm::Container
#                                Quản lý binding và tạo instance
#                                            v
#                                OutboxRepositoryInterface
#                                  Contract được yêu cầu
#                                            v
#                                     OutboxRepository
#                                Implementation được đăng ký
#                                            v
#                                      is_a? → true
#                                Implementation kế thừa Contract
#
#
#        3. So sánh Laravel
#                     interface OutboxRepositoryInterface
#                     {
#                         public function pending(int $limit = 100);
#                     }
#
#                     class OutboxRepository implements OutboxRepositoryInterface
#                     {
#                         public function pending(int $limit = 100)
#                         {
#                             return OutboxEvent::limit($limit)->get();
#                         }
#                     }
#
#
# Đăng ký vào Laravel Container:
#                   $this->app->bind(
#                       OutboxRepositoryInterface::class,
#                       OutboxRepository::class
#                   );
#
#
# Laravel Container cũng không implement OutboxRepositoryInterface. Chính OutboxRepository mới implement Interface.                         < quan trọng
#          Thành phần                            	Vai trò
#          OutboxRepositoryInterface	          Định nghĩa Contract
#          OutboxRepository	                  Triển khai Contract
#          Hrm::Container                    	Đăng ký, tạo và kiểm tra Implementation
#
# Lưu ý thêm: is_a? chỉ kiểm tra quan hệ kiểu dữ liệu (kế thừa Class hoặc include Module). Nó không chứng minh các phương thức đã được triển khai đầy đủ. Một lớp con chưa ghi đè pending vẫn có thể vượt qua is_a? nhưng phát sinh NotImplementedError khi gọi.
# Câu hỏi kiểm tra: Nếu OutboxRepository không kế thừa OutboxRepositoryInterface, thì instance.is_a?(OutboxRepositoryInterface) trả về true hay false?

# OutboxRepositoryInterface đang phục vụ cơ chế Outbox Event, có thể được sử dụng để gửi sự kiện Realtime, nhưng bản thân nó không trực tiếp thực hiện Realtime.              < quan trọng

# Trong hệ thống HRM của bạn, luồng có thể là:                                                  <                        < quan trọng
#                                       SalaryService / LeaveService
#                                                 |
#                                                 v
#                                       OutboxRepositoryInterface
#                                                 |
#                                                 | append!()
#                                                 v
#                                             OutboxEvent
#                                              (Database)
#                                                 |
#                                                 | pending()
#                                                 v
#                                           OutboxDispatchJob
#                                                 |
#                                                 | deliver(event:)
#                                                 v
#                                            Gửi sự kiện
#                                                 |
#                                            +----+----------+
#                                            |               |
#                                            v               v
#                                         Webhook         ActionCable
#                                         HTTP            Broadcast
#                                                            |
#                                                            v
#                                                      HrUpdatesChannel
#                                                            |
#                                                            v
#                                                       Frontend
#                                                       (Realtime)

# Phân biệt trách nhiệm                                                   <                        < quan trọng
# Thành phần	                                    Chức năng
# OutboxRepositoryInterface	            Quy định các phương thức lưu, lấy và xử lý sự kiện
# OutboxRepository	                    Triển khai lưu và xử lý Outbox
# OutboxEvent                         	Model lưu sự kiện trong Database
# OutboxDispatchJob	                    Worker xử lý các sự kiện chờ gửi
# ActionCable	                          Hệ thống WebSocket Realtime của Rails
# HrUpdatesChannel                    	Channel phát sự kiện HRM tới Client

# Ví dụ
# Khi nhân viên được duyệt đơn nghỉ phép:
#                 repository.append!(
#                   company_id: 10,
#                   event_type: "leave_request.reviewed",
#                   payload: {
#                     leave_request_id: 100,
#                     status: "approved"
#                   }
#                 )
#
#
# Sự kiện được lưu vào Outbox.
#
# Sau đó Worker có thể phát Realtime:
#                 ActionCable.server.broadcast(
#                   "company_10_hr_updates",
#                   {
#                     event: "leave_request.reviewed",
#                     status: "approved"
#                   }
#                 )
#
#
# So sánh với Laravel:
#               - OutboxRepositoryInterface       → Repository Contract.
#               - OutboxDispatchJob               → Laravel Queue Job.
#               - ActionCable                     → Laravel Reverb + Broadcasting.
#               - HrUpdatesChannel                → Laravel Broadcast Channel.
# Điểm quan trọng: Outbox không chỉ phục vụ Realtime. Nó còn có thể phục vụ Webhook, đồng bộ hệ thống ngoài, Integration và xử lý sự kiện bất đồng bộ.
#
# Chốt lại: OutboxRepositoryInterface thuộc tầng quản lý sự kiện; OutboxDispatchJob điều phối gửi; còn ActionCable mới trực tiếp đảm nhiệm Realtime qua WebSocket.

# 1. Phân biệt ba thành phần
#        Thành phần	                  Vai trò	                                      Laravel tương đương
#      ActiveRecord             	ORM, thao tác Database                             	Eloquent ORM
#      ActionCable	              Framework WebSocket Realtime                   	Laravel Reverb + Broadcasting
#      HrUpdatesChannel	 Channel do lập trình viên tạo để xử lý Realtime HRM	      Laravel Broadcast Channel
#
# Trong đó:
# - ActiveRecord có sẵn trong Rails.
# - ActionCable cũng có sẵn trong Rails, nhưng là framework riêng, không thuộc ActiveRecord.
# - HrUpdatesChannel là class do lập trình viên viết, thường nằm tại app/channels/hr_updates_channel.rb.
# 2. Cấu trúc thư mục Rails
#         app/
#         ├── models/
#         │   ├── application_record.rb
#         │   └── outbox_event.rb
#         │
#         ├── channels/
#         │   ├── application_cable/
#         │   │   ├── channel.rb
#         │   │   └── connection.rb
#         │   │
#         │   └── hr_updates_channel.rb
#         │
#         ├── jobs/
#         │   └── outbox_dispatch_job.rb
#         │
#         └── controllers/
#             └── salaries_controller.rb
#
#
# Ví dụ Model sử dụng ActiveRecord:
#                            class OutboxEvent < ApplicationRecord                                              < quan trọng
#                              scope :pending, -> { where(delivered_at: nil) }
#                            end
#
#
# Còn Channel sử dụng ActionCable:
#                            class HrUpdatesChannel < ApplicationCable::Channel                                              < quan trọng
#                              def subscribed
#                                stream_from "company_#{current_user.company_id}_hr_updates"
#                              end
#                            end
# > > >  Đây là hai hệ thống khác nhau.                                        < quan trọng
# 3. Chúng kết nối với nhau như thế nào?
#                             SalaryService
#                                   |
#                                   v
#                            OutboxRepository
#                                   |
#                                   v
#                             ActiveRecord
#                                   |
#                                   v
#                            Database (Outbox)
#                                   |
#                                   v
#                            OutboxDispatchJob
#                                   |
#                                   v
#                            ActionCable.server.broadcast(...)
#                                   |
#                                   v
#                             HrUpdatesChannel
#                                   |
#                                   v
#                             WebSocket Client
#
#
# Một điểm kỹ thuật quan trọng: ActionCable.server.broadcast(...) phát dữ liệu tới tên stream; HrUpdatesChannel đăng ký client theo dõi stream đó bằng stream_from. Job không nhất thiết gọi trực tiếp phương thức của HrUpdatesChannel.
#
# Ví dụ Job phát sự kiện:
#                   ActionCable.server.broadcast(
#                     "company_10_hr_updates",
#                     {
#                       event: "salary.updated",
#                       salary_id: 100
#                     }
#                   )
#
#
# Client đã subscribe vào stream company_10_hr_updates sẽ có thể nhận sự kiện này.
# 4. So sánh với Laravel
#               Ruby on Rails                 Laravel
#               ────────────────────────────────────────────
#               ActiveRecord                  Eloquent
#               OutboxEvent                   OutboxEvent Model
#               OutboxDispatchJob             Laravel Job
#               ActionCable                   Reverb + Broadcasting
#               HrUpdatesChannel              Broadcast Channel
#               stream_from                   Echo.private(...) / channel
#               ActionCable.server.broadcast  broadcast(new Event(...))
#
#
# Chốt lại: ActiveRecord chịu trách nhiệm dữ liệu, ActionCable chịu trách nhiệm truyền Realtime, còn HrUpdatesChannel là Channel HRM do bạn tự xây dựng trên ActionCable.
