module HrmIdentity
  module Domain
    module Repositories
      class WriteRepositoryInterface
        def revoke_personal_session!(actor:, credential:, id:) = raise(NotImplementedError)
        def issue_login_session!(user:)
          raise NotImplementedError, "HrmIdentity::WriteRepositoryInterface#issue_login_session!"
        end
        def revoke_login_session!(raw:)
          raise NotImplementedError, "HrmIdentity::WriteRepositoryInterface#revoke_login_session!"
        end
        def issue_token!(user:)
          raise NotImplementedError, "HrmIdentity::WriteRepositoryInterface##issue_token!"
        end
        def revoke_token!(token:)
          raise NotImplementedError, "HrmIdentity::WriteRepositoryInterface##revoke_token!"
        end
        def create_user!(attributes:)
          raise NotImplementedError, "HrmIdentity::WriteRepositoryInterface##create_user!"
        end
        def disable_user!(email:)
          raise NotImplementedError, "HrmIdentity::WriteRepositoryInterface##disable_user!"
        end
        def purge_expired_tokens
          raise NotImplementedError, "HrmIdentity::WriteRepositoryInterface##purge_expired_tokens"
        end
      end
    end
  end
end
