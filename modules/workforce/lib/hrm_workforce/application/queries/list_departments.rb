module HrmWorkforce
  module Application
    module Queries
      class ListDepartments < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @repository = repository
        end
        def call(actor:, page: 1)
          authorize!(actor, ::Department, :index?)
          @repository.departments(actor: actor, page: page)
        end
      end
    end
  end
end
