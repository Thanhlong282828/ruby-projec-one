module HrmIdentity
  module Application
    module Commands
      # Privileged local CLI entrypoint; not exposed by public HTTP routes.
      class ManageAccounts
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          @repository = repository
        end
        def create(attributes:) = @repository.create_user!(attributes: attributes)
        def disable(email:) = @repository.disable_user!(email: email)
        def purge_tokens = @repository.purge_expired_tokens
      end
    end
  end
end
