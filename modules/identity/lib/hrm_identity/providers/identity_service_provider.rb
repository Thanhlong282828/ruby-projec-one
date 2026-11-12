module HrmIdentity
  module Providers
    class IdentityServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmIdentity::Domain::Repositories::TenantReadRepositoryInterface", "HrmIdentity::Infrastructure::Persistence::ActiveRecordTenantReadRepository"
        bind "HrmIdentity::Domain::Repositories::TenantWriteRepositoryInterface", "HrmIdentity::Infrastructure::Persistence::ActiveRecordTenantWriteRepository"
        permissions = Rails.application.config.x.hrm.realtime_permissions || {}
        Rails.application.config.x.hrm.realtime_permissions = permissions.merge("system." => "system.companies.read", "company_context." => "dashboard.view")
        bind "HrmIdentity::Domain::Repositories::AdministrationRepositoryInterface", "HrmIdentity::Infrastructure::Persistence::ActiveRecordAdministrationRepository"
        bind "HrmIdentity::Domain::Repositories::ReadRepositoryInterface", "HrmIdentity::Infrastructure::Persistence::ActiveRecordReadRepository"
        bind "HrmIdentity::Domain::Repositories::WriteRepositoryInterface", "HrmIdentity::Infrastructure::Persistence::ActiveRecordWriteRepository"
      end
    end
  end
end
