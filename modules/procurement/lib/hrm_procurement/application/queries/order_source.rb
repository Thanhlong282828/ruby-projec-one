module HrmProcurement
  module Application
    module Queries
      class OrderSource < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:)
          authorize!(actor, ::PurchaseOrder, :create?)
          @repository.order_source(actor: actor, id: id)
        end
      end
    end
  end
end
