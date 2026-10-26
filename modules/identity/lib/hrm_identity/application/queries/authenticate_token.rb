module HrmIdentity
  module Application
    module Queries
      class AuthenticateToken
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @repository = repository
        end
        def call(raw:)
          token = @repository.valid_token(raw: raw)
          token if token&.user&.active?
        end
      end
    end
  end
end
