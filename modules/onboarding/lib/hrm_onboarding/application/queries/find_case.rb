module HrmOnboarding
  module Application
    module Queries
      class FindCase < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:)
          authorize!(actor, ::OnboardingCase, :index?)
          @repository.find!(actor: actor, id: id)
        end
      end
    end
  end
end
