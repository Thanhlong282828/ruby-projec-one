module HrmProcurement
  module Application
    module Queries
      class FindStockReceipt < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:)
          authorize!(actor, ::StockReceipt, :index?)
          @repository.find_stock_receipt!(actor: actor, id: id)
        end
      end
    end
  end
end
