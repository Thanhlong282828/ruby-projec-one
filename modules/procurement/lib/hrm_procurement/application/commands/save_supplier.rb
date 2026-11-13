module HrmProcurement
  module Application
    module Commands
      class SaveSupplier < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id: nil, attributes:, lock_version: nil)
          authorize!(actor, ::ProcurementSupplier, id ? :update? : :create?)
          @repository.save_supplier!(actor: actor, id: id, attributes: attributes, lock_version: lock_version)
        end
      end
    end
  end
end
