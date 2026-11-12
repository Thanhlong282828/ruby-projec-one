module HrmIntegration
  module Application
    module Commands
      class RotateConnectionSecret < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, lock_version:)
          authorize!(actor, ::IntegrationConnection, :update?)
          @repository.rotate!(actor: actor, id: id, lock_version: lock_version)
        end
      end
    end
  end
end
