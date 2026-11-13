module HrmProcurement
  module Application
    module Queries
      class StockReturnSource < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:)
          authorize!(actor, ::StockReturn, :create?)
          @repository.stock_return_source(actor: actor, id: id)
        end
      end
    end
  end
end
