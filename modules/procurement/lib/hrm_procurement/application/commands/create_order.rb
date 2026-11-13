module HrmProcurement
  module Application
    module Commands
      class CreateOrder < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, purchase_request_id:, supplier_id:, expected_on:)
          authorize!(actor, ::PurchaseOrder, :create?)
          @repository.create_order!(actor: actor, purchase_request_id: purchase_request_id, supplier_id: supplier_id, expected_on: expected_on)
        end
      end
    end
  end
end
