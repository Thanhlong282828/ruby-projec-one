module HrmOnboarding
  module Application
    module Queries
      class Workspace < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:)
          authorize!(actor, ::OnboardingCase, :index?)
          @repository.board(actor: actor)
        end
      end
    end
  end
end
