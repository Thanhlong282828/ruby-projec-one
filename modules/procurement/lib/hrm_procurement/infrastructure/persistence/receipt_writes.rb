module HrmProcurement
  module Infrastructure
    module Persistence
      module ReceiptWrites
        def receive_order!(actor:, id:, attributes:)
          ::GoodsReceipt.transaction do
            ActiveRecord::Base.uncached do
              context = WriteAuthorization.lock!(actor)
              Pundit.authorize(context, ::GoodsReceipt, :create?)
              order = Pundit.policy_scope!(context, ::PurchaseOrder).lock.find(Domain::Services::RequestFilters.id(id))
              Pundit.authorize(context, order, :show?)
              raise Domain::Services::RequestConflict, "Chỉ PO đã phát hành được nhận hàng" unless order.status == "issued"
              content = Domain::Services::ReceiptContent.read(attributes)
              digest = Domain::Services::ReceiptContent.digest(order.id, content)
              lines = order.lines.reorder(:id).lock.to_a.index_by(&:id)
              unless (content[:supplied_ids] - lines.keys).empty?
                raise Domain::Services::RequestContent::Invalid, "Dòng nhận không thuộc PO"
              end
              existing = ::GoodsReceipt.where(company_id: context.company_id, idempotency_key: content[:idempotency_key]).lock.first
              if existing
                unless existing.status == "recorded" && existing.content_digest == digest && existing.purchase_order_id == order.id
                  raise Domain::Services::RequestConflict, "Khóa thao tác đã được dùng với nội dung khác"
                end
                next existing
              end
              # Locking reads, rather than snapshot SUM, remain current inside an older caller transaction.
              received = ::GoodsReceiptLine.where(company_id: context.company_id, purchase_order_id: order.id).order(:id).lock.to_a.group_by(&:purchase_order_line_id)
              content[:items].each do |item|
                used = received.fetch(item[:purchase_order_line_id], []).sum(BigDecimal("0"), &:quantity)
                if item[:quantity] > lines.fetch(item[:purchase_order_line_id]).quantity - used
                  raise Domain::Services::RequestConflict, "Số lượng nhận vượt phần còn lại; hãy tải lại PO"
                end
              end
              record = ::GoodsReceipt.new(company_id: context.company_id, purchase_order: order, received_by_id: context.id,
                code: "GR-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}", received_on: content[:received_on],
                delivery_reference: content[:delivery_reference], idempotency_key: content[:idempotency_key], content_digest: digest)
              content[:items].each { |item| record.lines.build(item.merge(company_id: context.company_id, purchase_order_id: order.id)) }
              Current.set(user: actor) do
                record.save!
                record.update!(status: "recorded")
              end
              record
            end
          end
        end
      end
    end
  end
end
