module HrmOrganization
  module Application
    module Queries
      class Workspace < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          (@repository = repository)
        end
        def call(actor:, resource:, id: nil, page: 1)
          require_actor!(actor)
          if id
            record = @repository.find!(actor: actor, resource: resource, id: id)
            authorize!(actor, record, :show?)
            @repository.describe(actor: actor, resource: resource, record: record).merge(record: record)
          else
            authorize!(actor, Domain::Resources.model(resource), :index?)
            records = @repository.list(actor: actor, resource: resource, page: page)
            { records: records, rows: records.map { |record| @repository.describe(actor: actor, resource: resource, record: record) } }
          end
        end
      end
    end
  end
end
