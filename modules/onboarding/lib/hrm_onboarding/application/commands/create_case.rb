module HrmOnboarding
  module Application
    module Commands
      class CreateCase < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, attributes:)
          authorize!(actor, ::OnboardingCase, :create?)
          @repository.create!(actor: actor, attributes: attributes)
        end
      end
    end
  end
end
