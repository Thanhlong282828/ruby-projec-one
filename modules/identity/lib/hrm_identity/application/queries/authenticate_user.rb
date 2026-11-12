module HrmIdentity
  module Application
    module Queries
      class AuthenticateUser
        def self.dummy_digest
          @dummy_digest ||= BCrypt::Password.create(SecureRandom.hex(32),
            cost: ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost).to_s
        end
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @repository = repository
        end
        def call(email:, password:)
          return unless email.is_a?(String) && password.is_a?(String) && email.bytesize <= 254 && password.bytesize <= 72
          user = @repository.active_user_by_email(email: email)
          if user
            user if user.identity_user.authenticate(password)
          else
            BCrypt::Password.new(self.class.dummy_digest).is_password?(password)
            nil
          end
        end
      end
    end
  end
end
