module HrmProcurement
  module Application
    module Commands
      class IssueOrder < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, lock_version:)
          authorize!(actor, ::PurchaseOrder, :issue_any?)
          @repository.issue_order!(actor: actor, id: id, lock_version: lock_version)
        end
      end
    end
  end
end
