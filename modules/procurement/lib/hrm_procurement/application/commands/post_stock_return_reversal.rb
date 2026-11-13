module HrmProcurement
  module Application
    module Commands
      class PostStockReturnReversal < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, attributes:)
          authorize!(actor, ::StockReturnReversal, :index?)
          @repository.post_stock_return_reversal!(actor: actor, id: id, attributes: attributes)
        end
      end
    end
  end
end
