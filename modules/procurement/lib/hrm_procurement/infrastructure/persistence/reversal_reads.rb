module HrmProcurement
  module Infrastructure
    module Persistence
      module ReversalReads
        def stock_return_reversal_workspace(actor:, filters:)
          Pundit.authorize(actor, ::StockReturnReversal, :index?)
          scoped_workspace(Pundit.policy_scope!(actor, ::StockReturnReversal), filters, code: "code", title: "supplier_code_snapshot")
        end
        def find_stock_return_reversal!(actor:, id:)
          record = Pundit.policy_scope!(actor, ::StockReturnReversal).includes(:lines, :stock_return).find(Domain::Services::RequestFilters.id(id))
          Pundit.authorize(actor, record, :show?)
          { record: record, source_visible: Pundit.policy!(actor, record.stock_return).show? }
        end
        def stock_return_reversal_source(actor:, id:)
          Pundit.authorize(actor, ::StockReturnReversal, :create?)
          record = Pundit.policy_scope!(actor, ::StockReturn).includes(:lines).find(Domain::Services::RequestFilters.id(id))
          if ::StockReturnReversal.exists?(company_id: actor.company_id, stock_return_id: record.id)
            raise Domain::Services::RequestConflict, "Phiếu trả đã có chứng từ đảo"
          end
          { record: record }
        end
      end
    end
  end
end
