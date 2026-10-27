module HrmWorkforce
  module Application
    module Commands
      class CreateEmployee < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          @repository = repository
        end
        def call(actor:, attributes:)
          require_actor!(actor)
          record = @repository.build_employee(attributes: attributes)
          authorize!(actor, record, :create?)
          @repository.save!(record: record)
        end
      end
    end
  end
end
