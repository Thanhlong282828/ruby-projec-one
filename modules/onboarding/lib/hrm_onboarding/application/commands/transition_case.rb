module HrmOnboarding
  module Application
    module Commands
      class TransitionCase < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, status:, lock_version:)
          authorize!(actor, ::OnboardingCase, :update?)
          @repository.transition!(actor: actor, id: id, status: status, lock_version: lock_version)
        end
      end
    end
  end
end
