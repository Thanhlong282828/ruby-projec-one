module HrmProcurement
  module Infrastructure
    module Persistence
      module ReturnReads
        def stock_return_workspace(actor:, filters:)
          Pundit.authorize(actor, ::StockReturn, :index?)
          scoped_workspace(Pundit.policy_scope!(actor, ::StockReturn), filters, code: "code", title: "supplier_code_snapshot")
        end
        def find_stock_return!(actor:, id:)
          record = Pundit.policy_scope!(actor, ::StockReturn).includes(:lines, :stock_receipt).find(Domain::Services::RequestFilters.id(id))
          Pundit.authorize(actor, record, :show?)
          { record: record, source_visible: Pundit.policy!(actor, record.stock_receipt).show? }
        end
        def stock_return_source(actor:, id:)
          Pundit.authorize(actor, ::StockReturn, :create?)
          source = Pundit.policy_scope!(actor, ::StockReceipt).includes(:movements).find(Domain::Services::RequestFilters.id(id))
          { record: source, lines: stock_return_progress(source), can_return: true }
        end
        private
        def stock_return_progress(source)
          # An unsealed operator-created posting reserves quantity, failing closed like the seal guard.
          used = ::StockReturnLine.where(company_id: source.company_id, stock_receipt_id: source.id).group(:stock_movement_id).sum(:quantity)
          source.movements.map { |line| { movement: line, returned: used.fetch(line.id, BigDecimal("0")), remaining: line.quantity - used.fetch(line.id, BigDecimal("0")) } }
        end
        def signed_stock_scope(actor)
          # The inventory balance grant permits quantities for BOTH document kinds. Document links
          # independently require receipts.read / returns.read; return read scope must not hide stock.
          inbound = Pundit.policy_scope!(actor, ::StockMovement).select("stock_movements.id, stock_movements.company_id, stock_movements.warehouse_id, stock_movements.stock_item_id, stock_movements.quantity, stock_movements.item_code_snapshot, stock_movements.item_name_snapshot, stock_movements.unit, stock_movements.goods_receipt_line_id, stock_movements.purchase_order_line_id, stock_receipts.id AS document_id, stock_receipts.code AS document_code, stock_receipts.posted_at, 'receipt' AS document_kind")
          outbound = ::StockReturnLine.joins(:stock_return, :stock_movement).where(company_id: actor.company_id, stock_returns: { company_id: actor.company_id, status: "posted" })
            .select("stock_return_lines.id, stock_return_lines.company_id, stock_return_lines.warehouse_id, stock_return_lines.stock_item_id, -stock_return_lines.quantity AS quantity, stock_return_lines.item_code_snapshot, stock_return_lines.item_name_snapshot, stock_return_lines.unit, stock_movements.goods_receipt_line_id, stock_movements.purchase_order_line_id, stock_returns.id AS document_id, stock_returns.code AS document_code, stock_returns.posted_at, 'return' AS document_kind")
          union = Arel::Nodes::UnionAll.new(inbound.arel, outbound.arel)
          ::StockMovement.unscoped.from(Arel::Nodes::TableAlias.new(Arel::Nodes::Grouping.new(union), "stock_movements"))
        end
      end
    end
  end
end
