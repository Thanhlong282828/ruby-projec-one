module HrmOrganization
  module Providers
    class OrganizationServiceProvider < Hrm::ServiceProvider
      def register
        catalogs = Array(Rails.application.config.x.hrm.permission_catalogs)
        Rails.application.config.x.hrm.permission_catalogs = catalogs | [ "HrmOrganization::Domain::PermissionDefinitions" ]
        bind "HrmOrganization::Domain::Repositories::ReadRepositoryInterface", "HrmOrganization::Infrastructure::Persistence::ActiveRecordReadRepository"
        bind "HrmOrganization::Domain::Repositories::WriteRepositoryInterface", "HrmOrganization::Infrastructure::Persistence::ActiveRecordWriteRepository"
      end
    end
  end
end
