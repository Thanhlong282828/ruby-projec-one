module HrmOrganization
  module Application
    module Commands
      class DeleteRecord < Hrm::UseCase
        def initialize(read: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface), write: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @read, @write = read, write
        end
        def call(actor:, resource:, id:)
          require_actor!(actor)
          @write.within_company_lock(company_id: actor.company_id) do
            record = @read.find!(actor: actor, resource: resource, id: id)
            authorize!(actor, record, :destroy?)
            @write.destroy!(record: record)
          end
        end
      end
    end
  end
end
