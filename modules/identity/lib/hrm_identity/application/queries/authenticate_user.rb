module HrmIdentity
  module Application
    module Queries
      class AuthenticateUser
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @repository = repository
        end
        def call(email:, password:)
          user = @repository.active_user_by_email(email: email)
          user if user&.authenticate(password.to_s)
        end
      end
    end
  end
end
