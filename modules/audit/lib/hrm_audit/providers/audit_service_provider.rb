module HrmAudit
  module Providers
    class AuditServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmAudit::Domain::Repositories::ReadRepositoryInterface", "HrmAudit::Infrastructure::Persistence::ActiveRecordReadRepository"
        bind "HrmAudit::Domain::Repositories::WriteRepositoryInterface", "HrmAudit::Infrastructure::Persistence::ActiveRecordWriteRepository"
      end
    end
  end
end
