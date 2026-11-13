module HrmProcurement
  module Application
    module Queries
      class StockSource < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, item_search: nil, warehouse_search: nil)
          authorize!(actor, ::StockReceipt, :create?)
          @repository.stock_source(actor: actor, id: id, item_search: item_search, warehouse_search: warehouse_search)
        end
      end
    end
  end
end
