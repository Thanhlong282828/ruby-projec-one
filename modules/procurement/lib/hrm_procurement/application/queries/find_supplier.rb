module HrmProcurement
  module Application
    module Queries
      class FindSupplier < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:)
          authorize!(actor, ::ProcurementSupplier, :index?)
          @repository.find_supplier!(actor: actor, id: id)
        end
      end
    end
  end
end
