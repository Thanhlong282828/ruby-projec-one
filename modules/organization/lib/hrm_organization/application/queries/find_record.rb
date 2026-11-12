module HrmOrganization
  module Application
    module Queries
      class FindRecord < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          (@repository = repository)
        end
        def call(actor:, resource:, id:)
          require_actor!(actor)
          record = @repository.find!(actor: actor, resource: resource, id: id)
          authorize!(actor, record, :show?)
          record
        end
      end
    end
  end
end
