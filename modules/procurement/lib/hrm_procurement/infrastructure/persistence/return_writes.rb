module HrmProcurement
  module Infrastructure
    module Persistence
      module ReturnWrites
        def post_stock_return!(actor:, id:, attributes:)
          attempts = 0
          begin
            ::StockReturn.transaction(requires_new: true) do
              ActiveRecord::Base.uncached do
                context = WriteAuthorization.lock!(actor)
                Pundit.authorize(context, ::StockReturn, :index?)
                source = ::StockReceipt.where(company_id: context.company_id).lock.find(Domain::Services::RequestFilters.id(id))
                content = Domain::Services::ReturnContent.read(attributes)
                digest = Domain::Services::ReturnContent.digest(source.id, content)
                existing = ::StockReturn.where(company_id: context.company_id, idempotency_key: content[:idempotency_key]).lock.first
                if existing
                  Pundit.authorize(context, existing, :show?)
                  unless existing.status == "posted" && existing.stock_receipt_id == source.id && existing.content_digest == digest
                    raise Domain::Services::RequestConflict, "Khóa thao tác đã được dùng với nguồn hoặc nội dung trả khác"
                  end
                  next existing
                end
                Pundit.authorize(context, ::StockReturn, :create?)
                Pundit.authorize(context, source, :show?)
                raise Domain::Services::RequestConflict, "Chỉ được trả từ phiếu nhập đã ghi sổ" unless source.status == "posted"
                movements = source.movements.reorder(:id).lock.to_a.index_by(&:id)
                unless (content[:supplied_ids] - movements.keys).empty?
                  raise Domain::Services::RequestContent::Invalid, "Dòng trả không thuộc phiếu nhập nguồn"
                end
                # Current locking reads, never a consistent-read SUM from the caller's older snapshot.
                returned = net_returned_quantities(company_id: context.company_id, stock_receipt_id: source.id, lock: true)
                content[:items].each do |row|
                  used = returned.fetch(row[:stock_movement_id], BigDecimal("0"))
                  if row[:quantity] > movements.fetch(row[:stock_movement_id]).quantity - used
                    raise Domain::Services::RequestConflict, "Số lượng trả vượt phần còn lại của dòng nhập; hãy tải lại phiếu"
                  end
                end
                order = source.goods_receipt.purchase_order
                record = ::StockReturn.new(company_id: context.company_id, stock_receipt: source, warehouse_id: source.warehouse_id,
                  supplier_id: order.supplier_id, posted_by_id: context.id, code: "RT-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.hex(6).upcase}",
                  idempotency_key: content[:idempotency_key], content_digest: digest, reason: content[:reason],
                  warehouse_code_snapshot: source.warehouse_code_snapshot, warehouse_name_snapshot: source.warehouse_name_snapshot,
                  supplier_code_snapshot: order.supplier_code_snapshot, supplier_name_snapshot: order.supplier_name_snapshot)
                content[:items].each do |row|
                  movement = movements.fetch(row[:stock_movement_id])
                  record.lines.build(company_id: context.company_id, stock_receipt: source, stock_movement: movement,
                    warehouse_id: movement.warehouse_id, stock_item_id: movement.stock_item_id, quantity: row[:quantity],
                    item_code_snapshot: movement.item_code_snapshot, item_name_snapshot: movement.item_name_snapshot, unit: movement.unit)
                end
                Current.set(user: actor) do
                  record.save!
                  record.update!(status: "posted", posted_at: Time.current)
                end
                record
              end
            end
          rescue ActiveRecord::RecordNotUnique
            # The unique company/key fence also covers competing requests on DIFFERENT sources.
            # Retry outside the failed transaction; the normal locked path rechecks read grants/digest.
            attempts += 1
            retry if attempts == 1
            raise
          end
        end
      end
    end
  end
end
