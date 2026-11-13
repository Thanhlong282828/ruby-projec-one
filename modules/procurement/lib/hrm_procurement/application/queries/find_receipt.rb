module HrmProcurement
  module Application
    module Queries
      class FindReceipt < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:)
          authorize!(actor, ::GoodsReceipt, :index?)
          @repository.find_receipt!(actor: actor, id: id)
        end
      end
    end
  end
end
