module HrmWorkforce
  module Application
    module Commands
      class DeleteEmployee < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, record:)
          authorize!(actor, record, :destroy?)
          @repository.destroy(record: record)
        end
      end
    end
  end
end
