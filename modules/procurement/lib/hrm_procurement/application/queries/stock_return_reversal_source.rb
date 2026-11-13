module HrmProcurement
  module Application
    module Queries
      class StockReturnReversalSource < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:)
          authorize!(actor, ::StockReturnReversal, :create?)
          @repository.stock_return_reversal_source(actor: actor, id: id)
        end
      end
    end
  end
end
