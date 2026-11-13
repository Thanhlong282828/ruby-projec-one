module HrmProcurement
  module Application
    module Queries
      class Suppliers < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, search: nil, status: nil, page: nil)
          authorize!(actor, ::ProcurementSupplier, :index?)
          filters = Domain::Services::RequestFilters.read(search: search, page: page)
          filters[:status] = Hrm::ListFilters.choice(status, allowed: %w[active inactive])
          @repository.supplier_workspace(actor: actor, filters: filters.compact)
        end
      end
    end
  end
end
