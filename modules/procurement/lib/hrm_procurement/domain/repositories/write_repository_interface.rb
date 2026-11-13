module HrmProcurement
  module Domain
    module Repositories
      class WriteRepositoryInterface
        def post_stock_return!(actor:, id:, attributes:) = raise(NotImplementedError)
        def save_stock_catalog!(actor:, kind:, id:, attributes:, lock_version:) = raise(NotImplementedError)
        def post_stock_receipt!(actor:, id:, attributes:) = raise(NotImplementedError)
        def receive_order!(actor:, id:, attributes:) = raise(NotImplementedError)
        def save_supplier!(actor:, id:, attributes:, lock_version:) = raise(NotImplementedError)
        def create_order!(actor:, purchase_request_id:, supplier_id:, expected_on:) = raise(NotImplementedError)
        def update_order!(actor:, id:, attributes:, lock_version:) = raise(NotImplementedError)
        def issue_order!(actor:, id:, lock_version:) = raise(NotImplementedError)
        def create!(actor:, attributes:) = raise(NotImplementedError)
        def update!(actor:, id:, attributes:, lock_version:) = raise(NotImplementedError)
        def submit!(actor:, id:, lock_version:) = raise(NotImplementedError)
        def decide!(actor:, id:, decision:, reason:, lock_version:) = raise(NotImplementedError)
      end
    end
  end
end
