class OutboxEvent < ApplicationRecord # OutboxEvent kế thừa ORM từ ApplicationRecord, nên có thể sử dụng:OutboxEvent.all OutboxEvent.find(1) OutboxEvent.create(...) OutboxEvent.where(...)  |  Theo quy ước Rails, Model này tương ứng với bảng outbox_events.
  include CompanyOwned
  scope :pending, -> { where(delivered_at: nil) }
end

# Đoạn code này trong Ruby on Rails định nghĩa Model OutboxEvent, dùng để quản lý các sự kiện đang chờ được xử lý hoặc gửi đi trong hệ thống HRM/ERP.
# Nó liên quan trực tiếp đến Transactional Outbox Pattern và OutboxDispatchJob mà bạn đã học trước đó.
