module HrmOnboarding
  module Application
    module Queries
      class Workspace < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, status: nil, page: 1)
          authorize!(actor, ::OnboardingCase, :index?)
          @repository.board(actor: actor, status: Hrm::ListFilters.choice(status, allowed: Domain::Services::CaseStateMachine::TRANSITIONS.keys), page: page)
        end
      end
    end
  end
end
