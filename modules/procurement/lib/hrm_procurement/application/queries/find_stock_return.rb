module HrmProcurement
  module Application
    module Queries
      class FindStockReturn < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:)
          authorize!(actor, ::StockReturn, :index?)
          @repository.find_stock_return!(actor: actor, id: id)
        end
      end
    end
  end
end
