module HrmIntegration
  module Application
    module Queries
      class AuditWorkspace < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::AuditReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, from: nil, to: nil, resource: nil, operation: nil, record_id: nil, before: nil)
          authorize!(actor, [ :integration, ::AuditLog ], :index?)
          filters = Domain::Services::AuditFilters.new(from: from, to: to, resource: resource, operation: operation, record_id: record_id, before: before)
          @repository.workspace(actor: actor, filters: filters)
        end
      end
    end
  end
end
