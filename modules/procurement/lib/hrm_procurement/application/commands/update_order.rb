module HrmProcurement
  module Application
    module Commands
      class UpdateOrder < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, attributes:, lock_version:)
          authorize!(actor, ::PurchaseOrder, :update_any?)
          @repository.update_order!(actor: actor, id: id, attributes: attributes, lock_version: lock_version)
        end
      end
    end
  end
end
