module HrmAudit
  module Infrastructure
    module Persistence
      class ActiveRecordWriteRepository < Domain::Repositories::WriteRepositoryInterface
        def append!(actor:, action:, record:, changed_fields:)
          ::AuditLog.create!(actor: actor, action: action, record_type: record.class.name, record_id: record.id, metadata: { changed_fields: changed_fields })
        end
      end
    end
  end
end
