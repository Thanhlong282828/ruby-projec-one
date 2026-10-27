module HrmWorkforce
  module Application
    module Commands
      class UpdateEmployee < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          @repository = repository
        end
        def call(actor:, record:, attributes:)
          authorize!(actor, record, :update?)
          @repository.update!(record: record, attributes: attributes)
        end
      end
    end
  end
end
