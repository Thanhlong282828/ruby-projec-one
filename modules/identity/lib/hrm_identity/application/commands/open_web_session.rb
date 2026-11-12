module HrmIdentity
  module Application
    module Commands
      class OpenWebSession < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:)
          require_actor!(actor)
          @repository.issue_login_session!(user: actor)
        end
      end
    end
  end
end
