module HrmProcurement
  module Application
    module Commands
      class SaveStockCatalog < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, kind:, attributes:, id: nil, lock_version: nil)
          model = kind == :warehouse ? ::Warehouse : ::StockItem
          authorize!(actor, model, id ? :update? : :create?)
          @repository.save_stock_catalog!(actor: actor, kind: kind, id: id, attributes: attributes, lock_version: lock_version)
        end
      end
    end
  end
end
