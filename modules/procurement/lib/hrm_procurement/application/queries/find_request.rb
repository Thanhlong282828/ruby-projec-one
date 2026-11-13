module HrmProcurement
  module Application
    module Queries
      class FindRequest < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, history_page: nil)
          authorize!(actor, ::PurchaseRequest, :index?)
          @repository.find!(actor: actor, id: id, history_page: history_page)
        end
      end
    end
  end
end
