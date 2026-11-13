module HrmProcurement
  module Infrastructure
    module Persistence
      module ReversalWrites
        def post_stock_return_reversal!(actor:, id:, attributes:)
          attempts = 0
          begin
            ::StockReturnReversal.transaction(requires_new: true) do
              ActiveRecord::Base.uncached do
                context = WriteAuthorization.lock!(actor)
                Pundit.authorize(context, ::StockReturnReversal, :index?)
                source_id = Domain::Services::RequestFilters.id(id)
                receipt_id = ::StockReturn.where(company_id: context.company_id, id: source_id).pick(:stock_receipt_id)
                raise ActiveRecord::RecordNotFound unless receipt_id
                # Same first business lock as PostStockReturn; never lock RT before its IN.
                receipt = ::StockReceipt.where(company_id: context.company_id).lock.find(receipt_id)
                source = ::StockReturn.where(company_id: context.company_id).lock.find(source_id)
                content = Domain::Services::ReversalContent.read(attributes)
                digest = Domain::Services::ReversalContent.digest(source.id, content)
                existing = ::StockReturnReversal.where(company_id: context.company_id, idempotency_key: content[:idempotency_key]).lock.first
                if existing
                  Pundit.authorize(context, existing, :show?)
                  unless existing.status == "posted" && existing.stock_return_id == source.id && existing.content_digest == digest
                    raise Domain::Services::RequestConflict, "Khóa thao tác đã được dùng với nguồn hoặc lý do khác"
                  end
                  next existing
                end
                Pundit.authorize(context, ::StockReturnReversal, :create?)
                Pundit.authorize(context, source, :show?)
                raise Domain::Services::RequestConflict, "Chỉ được đảo phiếu trả đã ghi sổ" unless source.status == "posted"
                if ::StockReturnReversal.where(company_id: context.company_id, stock_return_id: source.id).lock.first
                  raise Domain::Services::RequestConflict, "Phiếu trả đã có chứng từ đảo; hãy tải lại"
                end
                receipt.movements.reorder(:id).lock.to_a
                # Re-read the same current net quantities as the return writer before restoring stock.
                net = net_returned_quantities(company_id: context.company_id, stock_receipt_id: receipt.id, lock: true)
                lines = source.lines.reorder(:id).lock.to_a
                unless lines.all? { |line| line.quantity <= net.fetch(line.stock_movement_id, BigDecimal("0")) }
                  raise Domain::Services::RequestConflict, "Lượng trả ròng không còn khớp phiếu nguồn; hãy kiểm tra sổ"
                end
                record = ::StockReturnReversal.new(company_id: context.company_id, stock_return: source, stock_receipt: receipt,
                  warehouse_id: source.warehouse_id, supplier_id: source.supplier_id, posted_by_id: context.id,
                  code: "RR-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.hex(6).upcase}",
                  idempotency_key: content[:idempotency_key], content_digest: digest, reason: content[:reason],
                  warehouse_code_snapshot: source.warehouse_code_snapshot, warehouse_name_snapshot: source.warehouse_name_snapshot,
                  supplier_code_snapshot: source.supplier_code_snapshot, supplier_name_snapshot: source.supplier_name_snapshot)
                lines.each do |line|
                  record.lines.build(company_id: context.company_id, stock_return: source, stock_return_line: line, stock_receipt: receipt,
                    stock_movement_id: line.stock_movement_id, warehouse_id: line.warehouse_id, stock_item_id: line.stock_item_id,
                    quantity: line.quantity, item_code_snapshot: line.item_code_snapshot, item_name_snapshot: line.item_name_snapshot, unit: line.unit)
                end
                Current.set(user: actor) do
                  record.save!
                  record.update!(status: "posted", posted_at: Time.current)
                end
                record
              end
            end
          rescue ActiveRecord::RecordNotUnique
            attempts += 1
            retry if attempts == 1
            raise
          end
        end
      end
    end
  end
end
