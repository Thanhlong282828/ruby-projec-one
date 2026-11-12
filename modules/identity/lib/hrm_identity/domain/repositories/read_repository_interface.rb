module HrmIdentity
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def personal_sessions(actor:, credential:, before: nil) = raise(NotImplementedError)
        def active_user(id:)
          raise NotImplementedError, "HrmIdentity::ReadRepositoryInterface##active_user"
        end
        def active_user_by_email(email:)
          raise NotImplementedError, "HrmIdentity::ReadRepositoryInterface##active_user_by_email"
        end
        def valid_login_session(raw:)
          raise NotImplementedError, "HrmIdentity::ReadRepositoryInterface#valid_login_session"
        end
        def valid_token(raw:)
          raise NotImplementedError, "HrmIdentity::ReadRepositoryInterface##valid_token"
        end
        def user_options(actor:)
          raise NotImplementedError, "HrmIdentity::ReadRepositoryInterface##user_options"
        end
        def summary_recipients(company_id:)
          raise NotImplementedError, "HrmIdentity::ReadRepositoryInterface##summary_recipients"
        end
      end
    end
  end
end
