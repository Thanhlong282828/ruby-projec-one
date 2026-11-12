module HrmPlatform
  module Infrastructure
    module Persistence
      class ActiveRecordOutboxRepository < Domain::Repositories::OutboxRepositoryInterface # A. Kế thừa Contract | Dấu < trong Ruby là kế thừa Class | Nó tương tự PHP: class ActiveRecordOutboxRepository implements OutboxRepositoryInterface { }  | Nhưng Ruby dùng class < ParentClass, còn PHP sử dụng implements với Interface. | Khi Container gọi: instance.is_a?( HrmPlatform::Domain::Repositories::OutboxRepositoryInterface )  < Kết quả sẽ là true đối với instance của class này.
        def append!(company_id:, event_type:, payload:) = ::OutboxEvent.create!(company_id: company_id, event_type: event_type, payload: payload) # 2. append! — lưu sự kiện vào Database
        # Ví dụ: repository.append!( company_id: 10, event_type: "salary.updated", payload: { salary_id: 100,amount: 20_000_000 })
        # ActiveRecord thực hiện thao tác INSERT vào bảng outbox_events. | Dấu ::OutboxEvent chỉ định class OutboxEvent ở namespace gốc, tránh Ruby tìm nhầm class trong HrmPlatform. | create! sẽ phát sinh exception nếu lưu thất bại, thay vì chỉ trả về object không hợp lệ.
        def pending(limit: 100) = ::OutboxEvent.pending.order(:id).limit(limit).to_a # 3. pending — lấy các sự kiện đang chờ  | Đặc biệt:  .to_a    < Chuyển ActiveRecord Relation thành Array và thực thi truy vấn để tải dữ liệu.
        # Trong Model trước đó của bạn:                                 Tương đương SQL:             Phương thức	                  Chức năng
        #     class OutboxEvent < ApplicationRecord                  SELECT *                         pending               	Lọc sự kiện chưa đánh dấu đã gửi
        #       scope :pending, -> { where(delivered_at: nil) }      FROM outbox_events               order(:id)	            Sắp xếp ID tăng dần
        #     end                                                    WHERE delivered_at IS NULL       limit(100)            	Lấy tối đa 100 sự kiện
        #                                                            ORDER BY id ASC                    to_a                  Thực thi truy vấn, lấy Array kết quả
        #                                                            LIMIT 100;
        def deliver(event:) # 4. deliver(event:) — phần quan trọng nhất  |
          #          Có ba bước chính:
          event.with_lock do # Bước 1 — with_lock | Khóa bản ghi Outbox trong transaction    |   event.with_lock do  < ActiveRecord sử dụng transaction và pessimistic row locking, thường tương đương: SELECT * FROM outbox_events WHERE id = 100 FOR UPDATE;  < Điều này giúp các Worker phối hợp xử lý cùng một bản ghi. < Ví dụ Worker A đã khóa Event 100 thì Worker B muốn khóa Event 100 phải chờ Worker A giải phóng khóa (tùy database và cấu hình timeout).
            return if event.delivered_at # Bước 2 — Kiểm tra delivered_at | Nếu đã gửi thì bỏ qua, nếu chưa thì chạy yield  |  return if event.delivered_at  < Nghĩa là: Nếu sự kiện đã có thời điểm gửi thì không gửi lại. Sau khi lấy khóa, ActiveRecord tải lại bản ghi nên có thể nhìn thấy trạng thái delivered_at mới nhất đã được commit.
            yield # yield thực thi Block được truyền vào phương thức.
            # Ví dụ: repository.deliver(event: event) do ActionCable.server.broadcast("company_10_hr_updates",{ event: "salary.updated" }) end   |  Khi đến yield, Ruby sẽ thực hiện:  ActionCable.server.broadcast(...)  | Quan trọng: yield không mặc định là Realtime. Nó chỉ chạy Block. Block có thể gửi Webhook, phát ActionCable hoặc thực hiện công việc khác.
            event.update!(delivered_at: Time.current) # Bước 3 — update! | Ghi thời điểm đã gửi thành công vào Database
            # Ví dụ: Trước: delivered_at = NULL Sau: delivered_at = 2026-11-09 09:36:00   |  Time.current sử dụng thời gian theo cấu hình timezone của Rails.
          end
        end
      end
    end
  end
end
# Đây chính là Implementation thực tế của OutboxRepositoryInterface mà bạn đã gửi trước đó.
# Nó thuộc tầng Infrastructure → Persistence trong kiến trúc Domain/Repository, sử dụng ActiveRecord để lưu sự kiện, lấy sự kiện chờ gửi và đánh dấu sự kiện đã gửi thành công.
# Điểm đặc biệt trong code này là with_lock kết hợp với yield để kiểm soát việc gửi sự kiện đồng thời.


# 5. So sánh với Laravel
# Một phiên bản Laravel gần tương đương:
#       class ActiveRecordOutboxRepository implements OutboxRepositoryInterface
#       {
#           public function append(
#               int $companyId,
#               string $eventType,
#               array $payload
#           ): OutboxEvent {
#               return OutboxEvent::create([
#                   'company_id' => $companyId,
#                   'event_type' => $eventType,
#                   'payload' => $payload,
#               ]);
#           }
#
#           public function pending(int $limit = 100)
#           {
#               return OutboxEvent::whereNull('delivered_at')
#                   ->orderBy('id')
#                   ->limit($limit)
#                   ->get();
#           }
#
#           public function deliver(OutboxEvent $event, callable $callback): void
#           {
#               DB::transaction(function () use ($event, $callback) {
#                   $lockedEvent = OutboxEvent::whereKey($event->id)
#                       ->lockForUpdate()
#                       ->firstOrFail();
#
#                   if ($lockedEvent->delivered_at !== null) {
#                       return;
#                   }
#
#                   $callback();
#
#                   $lockedEvent->update([
#                       'delivered_at' => now(),
#                   ]);
#               });
#           }
#       }

# Ruby on Rails                     	Laravel                                               <
# ::OutboxEvent.create!	        OutboxEvent::create()
# .pending                    scopePending() hoặc whereNull()
# .order(:id)                     	orderBy('id')
# .limit(limit)	                    limit($limit)
# .to_a                               	get()
# event.with_lock           	DB::transaction() + lockForUpdate()
# yield                             	$callback()
# Time.current                        	now()

# 6. Có đảm bảo Realtime không bị gửi trùng không?                                              <
# Chưa đảm bảo tuyệt đối. Đây là điểm rất quan trọng đối với hệ thống ERP/HRM.

# Giả sử:                                                                                          <
#       1. Worker A khóa Event 100.
#       2. Worker A chạy yield và gửi Webhook thành công.
#       3. Worker A gặp lỗi trước khi delivered_at được commit.
#       4. Transaction rollback, delivered_at vẫn NULL.
#       5. Worker B chạy lại và gửi cùng sự kiện.
# Kết quả: Webhook có thể bị gửi hai lần.

# Đây là cơ chế At-Least-Once Delivery, không phải Exactly-Once Delivery.

# Ngoài ra, code đang giữ database lock trong lúc chạy yield. Nếu Block thực hiện HTTP chậm, transaction sẽ giữ khóa lâu hơn.

# Để an toàn hơn trong production, thường cần:                                             < quan trọng
#        - Event ID duy nhất và cơ chế idempotency ở bên nhận.
#        - Retry có giới hạn và xử lý sự kiện thất bại.
#        - Cân nhắc claim/lease để tránh giữ transaction trong suốt thời gian gọi HTTP.
#        - Theo dõi sự kiện chưa gửi và sự kiện gửi thất bại.

# Chốt lại: ActiveRecordOutboxRepository là Implementation thực sự của OutboxRepositoryInterface.                                              < quan trọng
# Nó dùng ActiveRecord để thao tác database, with_lock để kiểm soát truy cập đồng thời và yield để thực thi công việc gửi sự kiện.                                             < quan trọng
# Nó phục vụ cơ chế Outbox, còn Realtime được thực hiện khi Block gọi ActionCable hoặc hệ thống phát sự kiện tương ứng.                                             < quan trọng
