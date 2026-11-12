module HrmOrganization
  module Application
    module Commands
      class UpdateRecord < Hrm::UseCase
        def initialize(read: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface), write: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @read, @write = read, write
        end
        def call(actor:, resource:, id:, attributes:)
          require_actor!(actor)
          @write.within_company_lock(company_id: actor.company_id) do
            record = @read.find!(actor: actor, resource: resource, id: id)
            authorize!(actor, record, :update?)
            @write.save!(record: record, attributes: attributes.slice(*Domain::Resources.fetch(resource).fetch(:fields).keys))
          end
        end
      end
    end
  end
end
