module HrmWorkforce
  module Application
    module Commands
      class CreateDepartment < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          @repository = repository
        end
        def call(actor:, attributes:)
          require_actor!(actor)
          record = @repository.build_department(attributes: attributes.except(:company_id, "company_id").merge(company_id: actor.company_id))
          authorize!(actor, record, :create?)
          @repository.save!(record: record)
        end
      end
    end
  end
end
