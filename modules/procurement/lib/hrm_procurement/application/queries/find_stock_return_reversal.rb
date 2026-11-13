module HrmProcurement
  module Application
    module Queries
      class FindStockReturnReversal < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:)
          authorize!(actor, ::StockReturnReversal, :index?)
          @repository.find_stock_return_reversal!(actor: actor, id: id)
        end
      end
    end
  end
end
