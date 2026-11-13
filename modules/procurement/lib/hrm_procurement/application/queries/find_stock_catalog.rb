module HrmProcurement
  module Application
    module Queries
      class FindStockCatalog < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, kind:, id:)
          authorize!(actor, ::Warehouse, :index?)
          @repository.find_stock_catalog!(actor: actor, kind: kind, id: id)
        end
      end
    end
  end
end
