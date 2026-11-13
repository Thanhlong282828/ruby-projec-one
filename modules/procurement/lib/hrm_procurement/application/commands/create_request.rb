module HrmProcurement
  module Application
    module Commands
      class CreateRequest < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, attributes:)
          authorize!(actor, ::PurchaseRequest, :create?)
          @repository.create!(actor: actor, attributes: attributes)
        end
      end
    end
  end
end
