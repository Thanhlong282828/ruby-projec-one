module HrmIdentity
  module Application
    module Commands
      class RevokePersonalSession < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, credential:, id:)
          require_actor!(actor)
          @repository.revoke_personal_session!(actor: actor, credential: credential, id: id)
        end
      end
    end
  end
end
