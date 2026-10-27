module HrmWorkforce
  module Application
    module Queries
      class ListEmployees < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @repository = repository
        end
        def call(actor:, page: 1, search: nil, api: false)
          authorize!(actor, ::Employee, :index?)
          @repository.employees(actor: actor, page: page, search: search, api: api)
        end
      end
    end
  end
end
