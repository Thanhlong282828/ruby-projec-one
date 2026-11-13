module HrmProcurement
  module Application
    module Queries
      class StockReturnReversals < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, search: nil, page: nil)
          authorize!(actor, ::StockReturnReversal, :index?)
          @repository.stock_return_reversal_workspace(actor: actor, filters: Domain::Services::RequestFilters.read(search: search, page: page))
        end
      end
    end
  end
end
