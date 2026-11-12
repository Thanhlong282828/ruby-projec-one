module HrmOrganization
  module Application
    module Queries
      class RecordForm < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          (@repository = repository)
        end
        def call(actor:, resource:, id: nil)
          require_actor!(actor)
          @repository.form(actor: actor, resource: resource, id: id)
        end
      end
    end
  end
end
