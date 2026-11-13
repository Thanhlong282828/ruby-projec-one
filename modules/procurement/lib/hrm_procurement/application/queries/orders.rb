module HrmProcurement
  module Application
    module Queries
      class Orders < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, search: nil, status: nil, page: nil, delivery: nil)
          authorize!(actor, ::PurchaseOrder, :index?)
          filters = Domain::Services::RequestFilters.read(search: search, page: page)
          filters[:status] = Hrm::ListFilters.choice(status, allowed: %w[draft issued])
          filters[:delivery] = Hrm::ListFilters.choice(delivery, allowed: %w[pending])
          @repository.order_workspace(actor: actor, filters: filters.compact)
        end
      end
    end
  end
end
