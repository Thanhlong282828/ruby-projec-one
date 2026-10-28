module HrmIdentity
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def active_user(id:)
          raise NotImplementedError, "HrmIdentity::ReadRepositoryInterface##active_user"
        end
        def active_user_by_email(email:)
          raise NotImplementedError, "HrmIdentity::ReadRepositoryInterface##active_user_by_email"
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
