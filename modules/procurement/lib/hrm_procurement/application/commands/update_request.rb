module HrmProcurement
  module Application
    module Commands
      class UpdateRequest < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, attributes:, lock_version:)
          authorize!(actor, ::PurchaseRequest, :update_any?)
          @repository.update!(actor: actor, id: id, attributes: attributes, lock_version: lock_version)
        end
      end
    end
  end
end
