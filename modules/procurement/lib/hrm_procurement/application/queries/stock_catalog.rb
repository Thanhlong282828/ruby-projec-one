module HrmProcurement
  module Application
    module Queries
      class StockCatalog < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, kind:, search: nil, status: nil, page: nil)
          authorize!(actor, ::Warehouse, :index?)
          @repository.stock_catalog_workspace(actor: actor, kind: kind, filters: Domain::Services::RequestFilters.read(search: search, page: page).merge(status: Hrm::ListFilters.choice(status, allowed: %w[active inactive])).compact)
        end
      end
    end
  end
end
