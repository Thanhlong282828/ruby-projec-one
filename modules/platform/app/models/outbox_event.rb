class OutboxEvent < ApplicationRecord # OutboxEvent kế thừa ORM từ ApplicationRecord, nên có thể sử dụng:OutboxEvent.all OutboxEvent.find(1) OutboxEvent.create(...) OutboxEvent.where(...)  |  Theo quy ước Rails, Model này tương ứng với bảng outbox_events.
  include CompanyOwned # B. include CompanyOwned | Khi include, OutboxEvent nhận các chức năng đã khai báo trong Concern, bao gồm quan hệ Company, scope for_company và validation ngăn chuyển công ty.
  scope :pending, -> { where(delivered_at: nil) } # C. scope :pending | Đây là Local Scope dùng để lấy những sự kiện chưa được đánh dấu là đã gửi thành công.
  #  Trong Ruby:
  # - scope :pending: Đặt tên scope là pending.
  # - -> { ... }: Lambda, định nghĩa logic truy vấn.
  # - where(delivered_at: nil): Lọc bản ghi có delivered_at IS NULL.
end

# Đoạn code này trong Ruby on Rails định nghĩa Model OutboxEvent, dùng để quản lý các sự kiện đang chờ được xử lý hoặc gửi đi trong hệ thống HRM/ERP.
# Nó liên quan trực tiếp đến Transactional Outbox Pattern và OutboxDispatchJob mà bạn đã học trước đó.

# B. include CompanyOwned
#          include CompanyOwned

# Bạn đã học Concern này:
#       module CompanyOwned
#         extend ActiveSupport::Concern

#         included do
#           belongs_to :company

#           scope :for_company, ->(company_id) {
#             where(company_id: company_id)
#           }
#         end
#       end
# Khi include, OutboxEvent nhận các chức năng đã khai báo trong Concern, bao gồm quan hệ Company, scope for_company và validation ngăn chuyển công ty.
# Ví dụ:
#     OutboxEvent.for_company(10)
# SQL tương đương:
# SELECT *
# FROM outbox_events
# WHERE company_id = 10;


# C. scope :pending
#       scope :pending, -> { where(delivered_at: nil) }


# Đây là Local Scope dùng để lấy những sự kiện chưa được đánh dấu là đã gửi thành công.

# Trong Ruby:
#     - scope :pending: Đặt tên scope là pending.
#     - -> { ... }: Lambda, định nghĩa logic truy vấn.
#     - where(delivered_at: nil): Lọc bản ghi có delivered_at IS NULL.
# Ví dụ:
#       OutboxEvent.pending
# SQL tương đương:
#       SELECT *
#       FROM outbox_events
#       WHERE delivered_at IS NULL;

# 2. Ví dụ dữ liệu Outbox
# Giả sử bảng outbox_events có dữ liệu:
# ID    	Company	      Event Type      	delivered_at
# 1	      10	        employee.created        	NULL
# 2	      10	        salary.updated    	2026-11-05 10:00
# 3     	20	    leave_request.reviewed      	NULL
# 4	      20	        employee.updated	        NULL

# Khi gọi:
#       OutboxEvent.pending               <
# Kết quả trả về ID 1, 3, 4.              <
# Khi gọi:
#          OutboxEvent.for_company(10).pending           <
# Chỉ trả về ID 1.                                    <
# Đây là khả năng kết hợp nhiều scope trong Rails.

# 3. Luồng xử lý Outbox trong HRM
#      SalaryService
#      Cập nhật bảng lương
#             v
#      OutboxEvent
#      Lưu sự kiện salary.updated, delivered_at = NULL
#             v
#      OutboxDispatchJob
#      Đọc các sự kiện pending
#             v
#      Webhook / Action Cable
#      Gửi sự kiện đến hệ thống nhận và phát Realtime
#             v
#      Đánh dấu đã gửi
#      delivered_at = thời điểm hoàn tất
# Ở bước cuối, việc cập nhật delivered_at phải do logic xử lý sự kiện thực hiện. Model bạn gửi chưa tự động cập nhật trường này.

# 4. So sánh với Laravel
# Rails:
#      class OutboxEvent < ApplicationRecord
#        include CompanyOwned

#        scope :pending, -> {
#          where(delivered_at: nil)
#        }
#      end

# Laravel:
#    use Illuminate\Database\Eloquent\Model;
#    use Illuminate\Database\Eloquent\Builder;

#    class OutboxEvent extends Model
#    {
#         use CompanyOwned;

#         public function scopePending(Builder $query): void
#         {
#             $query->whereNull('delivered_at');
#         }
#    }


# Sử dụng:
# Rails                               	Laravel
# OutboxEvent.pending           	  OutboxEvent::pending()->get()
# OutboxEvent.for_company(10)     	OutboxEvent::forCompany(10)->get()
# OutboxEvent.pending.count       	OutboxEvent::pending()->count()
# OutboxEvent.pending.first	        OutboxEvent::pending()->first()

# 5. Điểm quan trọng về Outbox Pattern
# delivered_at = NULL chỉ cho biết sự kiện chưa được đánh dấu là đã gửi thành công.

# Nó không nhất thiết chứng minh sự kiện chưa từng được gửi.

# Ví dụ:
# 1. Worker gửi Webhook thành công.
# 2. Worker bị lỗi trước khi cập nhật delivered_at.
# 3. Sự kiện vẫn có delivered_at = NULL.
# 4. Worker chạy lại và có thể gửi sự kiện lần nữa.
# Vì vậy, hệ thống Outbox thường cần cơ chế Idempotency, tránh xử lý trùng sự kiện dựa trên Event ID, cùng với cơ chế khóa hoặc claim sự kiện để hạn chế nhiều Worker xử lý đồng thời.

# Ngoài ra, include CompanyOwned không tự động giới hạn mọi truy vấn theo công ty. OutboxEvent.pending vẫn có thể lấy sự kiện của nhiều công ty, phù hợp với Worker hệ thống nếu Worker được thiết kế để xử lý toàn bộ tenant một cách an toàn.







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
