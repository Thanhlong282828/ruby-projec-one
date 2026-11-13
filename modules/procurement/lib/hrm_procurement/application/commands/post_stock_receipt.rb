module HrmProcurement
  module Application
    module Commands
      class PostStockReceipt < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, attributes:)
          authorize!(actor, ::StockReceipt, :index?)
          @repository.post_stock_receipt!(actor: actor, id: id, attributes: attributes)
        end
      end
    end
  end
end
