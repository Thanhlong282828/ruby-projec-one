module HrmOrganization
  module Application
    module Queries
      class ExportRecords < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          (@repository = repository)
        end
        def call(actor:, resource:)
          authorize!(actor, Domain::Resources.model(resource), :export?)
          @repository.export(actor: actor, resource: resource)
        end
      end
    end
  end
end
