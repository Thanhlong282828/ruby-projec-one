module HrmProcurement
  module Application
    module Commands
      class DecideRequest < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, decision:, reason: nil, lock_version:)
          authorize!(actor, ::PurchaseRequest, :review_queue?)
          @repository.decide!(actor: actor, id: id, decision: decision, reason: reason, lock_version: lock_version)
        end
      end
    end
  end
end
