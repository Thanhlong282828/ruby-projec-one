module HrmProcurement
  module Application
    module Commands
      class ReceiveOrder < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, attributes:)
          authorize!(actor, ::GoodsReceipt, :create?)
          @repository.receive_order!(actor: actor, id: id, attributes: attributes)
        end
      end
    end
  end
end
