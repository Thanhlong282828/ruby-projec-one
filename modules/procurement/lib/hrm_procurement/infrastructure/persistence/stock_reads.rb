module HrmProcurement
  module Infrastructure
    module Persistence
      module StockReads
        def stock_catalog_workspace(actor:, kind:, filters:)
          model = stock_read_model(kind)
          Pundit.authorize(actor, model, :index?)
          scoped_workspace(Pundit.policy_scope!(actor, model), filters, code: "code", title: "name").merge(kind: kind)
        end
        def find_stock_catalog!(actor:, kind:, id:)
          Pundit.policy_scope!(actor, stock_read_model(kind)).find(Domain::Services::RequestFilters.id(id))
        end
        def pending_stock_workspace(actor:, filters:)
          Pundit.authorize(actor, ::StockReceipt, :create?)
          scope = Pundit.policy_scope!(actor, ::GoodsReceipt).where.not(id: ::StockReceipt.where(company_id: actor.company_id).select(:goods_receipt_id)).includes(:purchase_order)
          scoped_workspace(scope, filters, code: "code", title: "code")
        end
        def stock_receipt_workspace(actor:, filters:)
          Pundit.authorize(actor, ::StockReceipt, :index?)
          scoped_workspace(Pundit.policy_scope!(actor, ::StockReceipt).includes(:goods_receipt), filters, code: "code", title: "warehouse_code_snapshot")
        end
        def find_stock_receipt!(actor:, id:)
          record = Pundit.policy_scope!(actor, ::StockReceipt).includes(:movements, goods_receipt: { purchase_order: :purchase_request }).find(Domain::Services::RequestFilters.id(id))
          Pundit.authorize(actor, record, :show?)
          progress = stock_return_progress(record)
          receipt = record.goods_receipt
          { record: record, return_lines: progress, can_return: Pundit.policy!(actor, ::StockReturn).create? && progress.any? { |row| row[:remaining].positive? }, receipt_visible: Pundit.policy!(actor, receipt).show?, order_visible: Pundit.policy!(actor, receipt.purchase_order).show?,
            source_visible: Pundit.policy!(actor, receipt.purchase_order.purchase_request).show? }
        end
        def stock_source(actor:, id:, item_search: nil, warehouse_search: nil)
          Pundit.authorize(actor, ::StockReceipt, :create?)
          source = Pundit.policy_scope!(actor, ::GoodsReceipt).includes(lines: :purchase_order_line).find(Domain::Services::RequestFilters.id(id))
          item_q = Domain::Services::RequestFilters.read(search: item_search)[:q]
          warehouse_q = Domain::Services::RequestFilters.read(search: warehouse_search)[:q]
          items = stock_options(::StockItem.where(company_id: actor.company_id, status: "active"), item_q).where(unit: source.lines.map { |line| line.purchase_order_line.unit }).limit(500).pluck(:name, :code, :unit, :id)
          { record: source, existing: Pundit.policy_scope!(actor, ::StockReceipt).find_by(goods_receipt_id: source.id), item_q: item_q, warehouse_q: warehouse_q,
            warehouses: stock_options(::Warehouse.where(company_id: actor.company_id, status: "active"), warehouse_q).limit(500).pluck(:name, :code, :id),
            options: source.lines.to_h { |line| [ line.id, items.select { |item| item[2] == line.purchase_order_line.unit }.map { |name, code, unit, id| [ "#{code} · #{name} (#{unit})", id ] } ] } }
        end
        def stock_balances(actor:, filters:)
          Pundit.authorize(actor, ::StockMovement, :index?)
          scope = signed_stock_scope(actor)
          scope = scope.where(warehouse_id: filters[:warehouse_id]) if filters[:warehouse_id]
          grouped = scope.group(:warehouse_id, :stock_item_id).select("stock_movements.warehouse_id, stock_movements.stock_item_id, SUM(stock_movements.quantity) AS balance_quantity")
          count = ::StockMovement.unscoped.from(grouped, :stock_movements).count
          records = grouped.order(:warehouse_id, :stock_item_id).limit(25).offset((filters.fetch(:page) - 1) * 25).to_a
          warehouses = ::Warehouse.where(company_id: actor.company_id, id: records.map(&:warehouse_id)).index_by(&:id)
          items = ::StockItem.where(company_id: actor.company_id, id: records.map(&:stock_item_id)).index_by(&:id)
          rows = records.map { |row| { warehouse: warehouses.fetch(row.warehouse_id), item: items.fetch(row.stock_item_id), quantity: row[:balance_quantity] } }
          { records: rows, count: count, filters: filters, warehouses: ::Warehouse.where(company_id: actor.company_id).order(:code).pluck(:name, :code, :id, :status) }
        end
        def stock_ledger(actor:, filters:)
          Pundit.authorize(actor, ::StockMovement, :index?)
          warehouse = ::Warehouse.where(company_id: actor.company_id).find(filters.fetch(:warehouse_id))
          item = ::StockItem.where(company_id: actor.company_id).find(filters.fetch(:stock_item_id))
          scope = signed_stock_scope(actor).where(warehouse_id: warehouse.id, stock_item_id: item.id)
          records = scope.order(posted_at: :desc, document_kind: :asc, id: :desc).limit(25).offset((filters.fetch(:page) - 1) * 25).to_a
          { records: records, count: scope.count, quantity: scope.sum(:quantity), warehouse: warehouse, item: item,
            filters: filters, receipts_visible: Pundit.policy!(actor, ::StockReceipt).index?, returns_visible: Pundit.policy!(actor, ::StockReturn).index? }
        end
        private
        def stock_read_model(kind)
          case kind
          when :warehouse then ::Warehouse
          when :item then ::StockItem
          else raise ActiveRecord::RecordNotFound
          end
        end
        def stock_options(scope, term)
          if term.present?
            pattern = "%#{scope.klass.sanitize_sql_like(term)}%"
            table = scope.klass.arel_table
            scope = scope.where(table[:code].matches(pattern).or(table[:name].matches(pattern)))
          end
          scope.order(:code, :id)
        end
      end
    end
  end
end
