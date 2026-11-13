module HrmProcurement
  module Application
    module Queries
      class StockReturns < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, search: nil, page: nil)
          authorize!(actor, ::StockReturn, :index?)
          @repository.stock_return_workspace(actor: actor, filters: Domain::Services::RequestFilters.read(search: search, page: page))
        end
      end
    end
  end
end
