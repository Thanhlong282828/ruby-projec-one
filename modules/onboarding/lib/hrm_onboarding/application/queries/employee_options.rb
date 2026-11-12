module HrmOnboarding
  module Application
    module Queries
      class EmployeeOptions < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:)
          authorize!(actor, ::OnboardingCase, :create?)
          @repository.employee_options(actor: actor)
        end
      end
    end
  end
end
