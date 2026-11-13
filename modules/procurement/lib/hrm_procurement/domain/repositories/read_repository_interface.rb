module HrmProcurement
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def receipt_workspace(actor:, filters:) = raise(NotImplementedError)
        def find_receipt!(actor:, id:) = raise(NotImplementedError)
        def receiving_source(actor:, id:) = raise(NotImplementedError)
        def supplier_workspace(actor:, filters:) = raise(NotImplementedError)
        def find_supplier!(actor:, id:) = raise(NotImplementedError)
        def order_workspace(actor:, filters:) = raise(NotImplementedError)
        def find_order!(actor:, id:, history_page: nil) = raise(NotImplementedError)
        def order_source(actor:, id:) = raise(NotImplementedError)
        def workspace(actor:, filters:, recent: false) = raise(NotImplementedError)
        def find!(actor:, id:, history_page: 1) = raise(NotImplementedError)
      end
    end
  end
end
