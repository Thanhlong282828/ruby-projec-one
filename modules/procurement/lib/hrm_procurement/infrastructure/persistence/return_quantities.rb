module HrmProcurement
  module Infrastructure
    module Persistence
      module ReturnQuantities
        private
        def net_returned_quantities(company_id:, stock_receipt_id:, lock: false)
          returns = ::StockReturnLine.where(company_id: company_id, stock_receipt_id: stock_receipt_id).order(:id)
          reversed = ::StockReturnReversalLine.joins(:stock_return_reversal).where(company_id: company_id, stock_receipt_id: stock_receipt_id,
            stock_return_reversals: { company_id: company_id, status: "posted" }).order("stock_return_reversal_lines.id")
          # With the shared receipt lock held, these are CURRENT locking reads, including under
          # a caller's older REPEATABLE READ snapshot. Only sealed reversals restore entitlement.
          returns = returns.lock if lock
          reversed = reversed.lock if lock
          restored = reversed.to_a.index_by(&:stock_return_line_id)
          returns.to_a.each_with_object(Hash.new { |h, k| h[k] = BigDecimal("0") }) do |line, quantities|
            quantities[line.stock_movement_id] += line.quantity - (restored[line.id]&.quantity || BigDecimal("0"))
          end
        end
      end
    end
  end
end
