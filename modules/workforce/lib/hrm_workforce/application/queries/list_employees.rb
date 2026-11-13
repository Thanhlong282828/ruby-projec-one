module HrmWorkforce
  module Application
    module Queries
      class ListEmployees < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, page: 1, search: nil, api: false, status: nil)
          authorize!(actor, ::Employee, :index?)
          @repository.employees(actor: actor, page: page, search: search, api: api, status: Hrm::ListFilters.choice(status, allowed: %w[active probation inactive]))
        end
      end
    end
  end
end
