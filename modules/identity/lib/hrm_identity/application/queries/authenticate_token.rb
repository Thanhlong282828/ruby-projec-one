module HrmIdentity
  module Application
    module Queries
      class AuthenticateToken
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @repository = repository
        end
        def call(raw:)
          token = @repository.valid_token(raw: raw)
          token if token&.user&.enabled_for_access? && token.principal_user_id == token.user.identity_id
        end
      end
    end
  end
end
