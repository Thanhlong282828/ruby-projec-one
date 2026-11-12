module HrmIdentity
  module Application
    module Queries
      class PersonalSessions < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, credential:, before: nil)
          require_actor!(actor)
          Pundit.authorize(actor, ::LoginSession, :index?, policy_class: ::PersonalSessionPolicy)
          @repository.personal_sessions(actor: actor, credential: credential, before: before)
        end
      end
    end
  end
end
