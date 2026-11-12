module HrmOrganization
  module Application
    module Commands
      class CreateRecord < Hrm::UseCase
        def initialize(write: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          (@write = write)
        end
        def call(actor:, resource:, attributes:)
          require_actor!(actor)
          @write.within_company_lock(company_id: actor.company_id) do
            record = @write.build(resource: resource, company_id: actor.company_id, attributes: attributes.slice(*Domain::Resources.fetch(resource).fetch(:fields).keys))
            authorize!(actor, record, :create?)
            @write.save!(record: record)
          end
        end
      end
    end
  end
end
