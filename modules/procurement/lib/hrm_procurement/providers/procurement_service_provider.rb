module HrmProcurement
  module Providers
    class ProcurementServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmProcurement::Domain::Repositories::ReadRepositoryInterface", "HrmProcurement::Infrastructure::Persistence::ActiveRecordReadRepository"
        bind "HrmProcurement::Domain::Repositories::WriteRepositoryInterface", "HrmProcurement::Infrastructure::Persistence::ActiveRecordWriteRepository"
        catalogs = Array(Rails.application.config.x.hrm.permission_catalogs)
        Rails.application.config.x.hrm.permission_catalogs = catalogs | [ "HrmProcurement::Domain::PermissionDefinitions" ]
        permissions = Rails.application.config.x.hrm.realtime_permissions || {}
        Rails.application.config.x.hrm.realtime_permissions = permissions.merge("purchase_request." => "procurement.requests.read_all")
      end
    end
  end
end
