# typed: strict

module HrmIdentity
  module Application
    module Commands
      class RevokePersonalSession < Hrm::UseCase
        extend T::Sig
        sig { params(repository: Domain::Repositories::WriteRepositoryInterface).void }
        def initialize(repository: T.cast(Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface), Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = T.let(repository, Domain::Repositories::WriteRepositoryInterface) # Restore the reloadable Container contract.
        end
        # Raw id/credential values reach explicit guards; Object includes nil without coercion.
        sig { params(actor: T.nilable(User), credential: Object, id: Object).returns(T.nilable(AuditLog)) }
        def call(actor:, credential:, id:)
          require_actor!(actor)
          actor = T.must(actor) # require_actor! rejects nil before narrowing.
          @repository.revoke_personal_session!(actor: actor, credential: credential, id: id)
        end
      end
    end
  end
end
