module HrmProcurement
  module Application
    module Commands
      class PostStockReturn < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, attributes:)
          authorize!(actor, ::StockReturn, :index?)
          @repository.post_stock_return!(actor: actor, id: id, attributes: attributes)
        end
      end
    end
  end
end
