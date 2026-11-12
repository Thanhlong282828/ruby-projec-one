module HrmOnboarding
  module Application
    module Commands
      class CompleteChecklist < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, code:, lock_version:)
          authorize!(actor, ::OnboardingCase, :update?)
          @repository.complete!(actor: actor, id: id, code: code, lock_version: lock_version)
        end
      end
    end
  end
end
