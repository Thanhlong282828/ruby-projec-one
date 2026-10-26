module HrmIdentity
  module Application
    module Commands
      class IssueToken < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          @repository = repository
        end
        def call(actor:)
          require_actor!(actor)
          @repository.issue_token!(user: actor)
        end
      end
    end
  end
end
