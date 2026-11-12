module HrmOrganization
  module Application
    module Queries
      class ListRecords < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          (@repository = repository)
        end
        def call(actor:, resource:, page: 1)
          authorize!(actor, Domain::Resources.model(resource), :index?)
          @repository.list(actor: actor, resource: resource, page: page)
        end
      end
    end
  end
end
