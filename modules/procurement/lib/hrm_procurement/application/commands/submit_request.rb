module HrmProcurement
  module Application
    module Commands
      class SubmitRequest < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, lock_version:)
          authorize!(actor, ::PurchaseRequest, :submit_any?)
          @repository.submit!(actor: actor, id: id, lock_version: lock_version)
        end
      end
    end
  end
end
