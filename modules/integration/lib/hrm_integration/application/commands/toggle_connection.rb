module HrmIntegration
  module Application
    module Commands
      class ToggleConnection < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, active:, lock_version:)
          authorize!(actor, ::IntegrationConnection, :update?)
          @repository.change_status!(actor: actor, id: id, active: active, lock_version: lock_version)
        end
      end
    end
  end
end
