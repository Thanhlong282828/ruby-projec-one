module HrmProcurement
  module Application
    module Queries
      class StockBalances < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, warehouse_id: nil, page: nil)
          authorize!(actor, ::StockMovement, :index?)
          @repository.stock_balances(actor: actor, filters: { warehouse_id: warehouse_id.blank? ? nil : Domain::Services::RequestFilters.id(warehouse_id), page: Domain::Services::RequestFilters.page_number(page) }.compact)
        end
      end
    end
  end
end
