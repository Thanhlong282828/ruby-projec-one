module HrmIdentity
  module Application
    module Commands
      # Revokes possession of this opaque credential only; never accepts a user ID.
      class CloseWebSession
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          @repository = repository
        end
        def call(raw:)
          @repository.revoke_login_session!(raw: raw) if raw.is_a?(String) && raw.bytesize == 64
        end
      end
    end
  end
end
