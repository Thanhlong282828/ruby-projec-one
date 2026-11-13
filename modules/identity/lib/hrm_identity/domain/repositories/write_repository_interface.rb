# typed: strict

module HrmIdentity
  module Domain
    module Repositories
      class WriteRepositoryInterface
        extend T::Sig
        sig { overridable.params(actor: User, credential: Object, id: Object).returns(T.nilable(AuditLog)) }
        def revoke_personal_session!(actor:, credential:, id:) = raise(NotImplementedError)
        sig { overridable.params(user: User).returns(T.nilable(String)) }
        def issue_login_session!(user:)
          raise NotImplementedError, "HrmIdentity::WriteRepositoryInterface#issue_login_session!"
        end
        sig { overridable.params(raw: Object).returns(Integer) }
        def revoke_login_session!(raw:)
          raise NotImplementedError, "HrmIdentity::WriteRepositoryInterface#revoke_login_session!"
        end
        sig { overridable.params(user: User).returns(T.nilable(String)) }
        def issue_token!(user:)
          raise NotImplementedError, "HrmIdentity::WriteRepositoryInterface##issue_token!"
        end
        sig { overridable.params(token: ApiToken).returns(ApiToken) }
        def revoke_token!(token:)
          raise NotImplementedError, "HrmIdentity::WriteRepositoryInterface##revoke_token!"
        end
        sig { overridable.params(attributes: T::Hash[Symbol, Object]).returns(User) }
        def create_user!(attributes:)
          raise NotImplementedError, "HrmIdentity::WriteRepositoryInterface##create_user!"
        end
        sig { overridable.params(email: Object).returns(T.nilable(T::Array[ApiToken])) }
        def disable_user!(email:)
          raise NotImplementedError, "HrmIdentity::WriteRepositoryInterface##disable_user!"
        end
        sig { overridable.returns(Integer) }
        def purge_expired_tokens
          raise NotImplementedError, "HrmIdentity::WriteRepositoryInterface##purge_expired_tokens"
        end
      end
    end
  end
end
