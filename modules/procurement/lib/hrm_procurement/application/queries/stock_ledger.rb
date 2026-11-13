module HrmProcurement
  module Application
    module Queries
      class StockLedger < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, warehouse_id:, stock_item_id:, page: nil)
          authorize!(actor, ::StockMovement, :index?)
          @repository.stock_ledger(actor: actor, filters: {
            warehouse_id: Domain::Services::RequestFilters.id(warehouse_id),
            stock_item_id: Domain::Services::RequestFilters.id(stock_item_id),
            page: Domain::Services::RequestFilters.page_number(page)
          })
        end
      end
    end
  end
end
