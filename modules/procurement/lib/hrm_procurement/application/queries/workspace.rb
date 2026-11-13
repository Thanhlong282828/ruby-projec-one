module HrmProcurement
  module Application
    module Queries
      class Workspace < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, search: nil, status: nil, view: nil, page: nil)
          authorize!(actor, ::PurchaseRequest, :index?)
          filters = Domain::Services::RequestFilters.read(search: search, status: status, view: view, page: page)
          @repository.workspace(actor: actor, filters: filters)
        end
      end
    end
  end
end
