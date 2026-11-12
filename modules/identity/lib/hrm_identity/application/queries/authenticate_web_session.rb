module HrmIdentity
  module Application
    module Queries
      class AuthenticateWebSession
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @repository = repository
        end
        def call(raw:)
          return unless raw.is_a?(String) && /\A[A-Za-z0-9_-]{64}\z/.match?(raw)
          login = @repository.valid_login_session(raw: raw)
          login if login&.user&.enabled_for_access? && login.principal_user_id == login.user.identity_id
        end
      end
    end
  end
end
