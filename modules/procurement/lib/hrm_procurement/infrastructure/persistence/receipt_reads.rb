module HrmProcurement
  module Infrastructure
    module Persistence
      module ReceiptReads
        def receipt_workspace(actor:, filters:)
          Pundit.authorize(actor, ::GoodsReceipt, :index?)
          scoped_workspace(Pundit.policy_scope!(actor, ::GoodsReceipt), filters, code: "code", title: "code")
        end
        def find_receipt!(actor:, id:)
          record = Pundit.policy_scope!(actor, ::GoodsReceipt).includes(lines: :purchase_order_line, purchase_order: :purchase_request).find(Domain::Services::RequestFilters.id(id))
          Pundit.authorize(actor, record, :show?)
          { record: record, order_visible: Pundit.policy!(actor, record.purchase_order).show?, source_visible: Pundit.policy!(actor, record.purchase_order.purchase_request).show? }
        end
        def receiving_source(actor:, id:)
          Pundit.authorize(actor, ::GoodsReceipt, :create?)
          detail = find_order!(actor: actor, id: id)
          raise Domain::Services::RequestConflict, "Chỉ PO đã phát hành được nhận hàng" unless detail[:record].status == "issued"
          detail
        end
        private
        def receiving_pending(scope)
          # Correlated fixed SQL: both operands bind through same-company/order foreign keys.
          scope.where(status: "issued").where(<<~SQL.squish)
            EXISTS (SELECT 1 FROM purchase_order_lines pol
              WHERE pol.company_id=purchase_orders.company_id AND pol.purchase_order_id=purchase_orders.id
              AND pol.quantity > (SELECT COALESCE(SUM(grl.quantity),0) FROM goods_receipt_lines grl
                INNER JOIN goods_receipts gr ON gr.id=grl.goods_receipt_id AND gr.company_id=grl.company_id
                WHERE grl.company_id=pol.company_id AND grl.purchase_order_line_id=pol.id AND gr.status='recorded'))
          SQL
        end
        def receiving_quantities(records)
          ids = records.map(&:id)
          ::GoodsReceiptLine.joins(:goods_receipt).where(purchase_order_id: ids, company_id: records.map(&:company_id).uniq, goods_receipts: { status: "recorded" }).group(:purchase_order_line_id).sum(:quantity)
        end
        def receiving_progress(record, quantities)
          return "Chưa nhận" if record.lines.all? { |line| quantities.fetch(line.id, 0).zero? }
          record.lines.all? { |line| quantities.fetch(line.id, 0) >= line.quantity } ? "Đã nhận đủ" : "Nhận một phần"
        end
      end
    end
  end
end
