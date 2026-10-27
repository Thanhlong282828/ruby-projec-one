module HrmIdentity
  module Application
    module Commands
      class RevokeToken < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          @repository = repository
        end
        def call(actor:, token:)
          require_actor!(actor)
          raise Pundit::NotAuthorizedError unless token.user_id == actor.id
          @repository.revoke_token!(token: token)
        end
      end
    end
  end
end
