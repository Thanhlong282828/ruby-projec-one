module HrmProcurement
  module Infrastructure
    module Persistence
      module StockWrites
        def save_stock_catalog!(actor:, kind:, id:, attributes:, lock_version:)
          model = stock_catalog_model(kind)
          model.transaction do
            ActiveRecord::Base.uncached do
              context = WriteAuthorization.lock!(actor)
              record = id ? Pundit.policy_scope!(context, model).lock.find(Domain::Services::RequestFilters.id(id)) : model.new(company_id: context.company_id)
              Pundit.authorize(context, record, id ? :update? : :create?)
              order_version!(record, lock_version, "update") if id
              record.assign_attributes(Domain::Services::StockContent.catalog(attributes, kind: kind))
              Current.set(user: actor) { record.save! }
              record
            end
          end
        end
        def post_stock_receipt!(actor:, id:, attributes:)
          ::StockReceipt.transaction do
            ActiveRecord::Base.uncached do
              context = WriteAuthorization.lock!(actor)
              source = ::GoodsReceipt.where(company_id: context.company_id).lock.find(Domain::Services::RequestFilters.id(id))
              Pundit.authorize(context, ::StockReceipt, :index?)
              raise Domain::Services::RequestConflict, "Phiếu nhận chưa ghi nhận" unless source.status == "recorded"
              content = Domain::Services::StockContent.mapping(attributes)
              digest = Domain::Services::StockContent.digest(source.id, content)
              existing = ::StockReceipt.where(company_id: context.company_id, goods_receipt_id: source.id).lock.first
              if existing
                Pundit.authorize(context, existing, :show?)
                unless existing.status == "posted" && existing.mapping_digest == digest
                  raise Domain::Services::RequestConflict, "Phiếu đã nhập với kho hoặc ánh xạ khác"
                end
                next existing # Read-only replay rechecks the current entry read grant.
              end
              Pundit.authorize(context, ::StockReceipt, :create?)
              Pundit.authorize(context, source, :show?)
              lines = source.lines.reorder(:id).lock.to_a.index_by(&:id)
              unless content[:items].map { |row| row[:goods_receipt_line_id] }.sort == lines.keys.sort
                raise Domain::Services::RequestContent::Invalid, "Phải ánh xạ đúng và đủ từng dòng phiếu nhận"
              end
              warehouse = ::Warehouse.where(company_id: context.company_id, status: "active").lock.find(content[:warehouse_id])
              ids = content[:items].map { |row| row[:stock_item_id] }.uniq.sort
              items = ::StockItem.where(company_id: context.company_id, status: "active", id: ids).order(:id).lock.to_a.index_by(&:id)
              raise ActiveRecord::RecordNotFound unless items.keys.sort == ids
              order_lines = ::PurchaseOrderLine.where(company_id: context.company_id, id: lines.values.map(&:purchase_order_line_id)).order(:id).lock.to_a.index_by(&:id)
              record = ::StockReceipt.new(company_id: context.company_id, goods_receipt: source, warehouse: warehouse, posted_by_id: context.id,
                code: "IN-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.hex(6).upcase}", mapping_digest: digest,
                warehouse_code_snapshot: warehouse.code, warehouse_name_snapshot: warehouse.name)
              content[:items].each do |row|
                line = lines.fetch(row[:goods_receipt_line_id])
                item = items.fetch(row[:stock_item_id])
                unless item.unit == order_lines.fetch(line.purchase_order_line_id).unit
                  raise Domain::Services::RequestContent::Invalid, "Đơn vị mã hàng phải khớp chính xác dòng PO; chưa hỗ trợ quy đổi"
                end
                record.movements.build(company_id: context.company_id, goods_receipt_id: source.id, goods_receipt_line: line,
                  purchase_order_line_id: line.purchase_order_line_id, warehouse: warehouse, stock_item: item, quantity: line.quantity,
                  item_code_snapshot: item.code, item_name_snapshot: item.name, unit: item.unit)
              end
              Current.set(user: actor) do
                record.save!
                record.update!(status: "posted", posted_at: Time.current)
              end
              record
            end
          end
        end
        private
        def stock_catalog_model(kind)
          case kind
          when :warehouse then ::Warehouse
          when :item then ::StockItem
          else raise ActiveRecord::RecordNotFound
          end
        end
      end
    end
  end
end
