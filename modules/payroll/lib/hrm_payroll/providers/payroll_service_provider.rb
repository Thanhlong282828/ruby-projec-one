module HrmPayroll
  module Providers
    class PayrollServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmPayroll::Domain::Repositories::ExportSourceRepositoryInterface", "HrmPayroll::Infrastructure::Persistence::ActiveRecordExportSourceRepository"
        bind "HrmPayroll::Domain::Repositories::ExportReadRepositoryInterface", "HrmPayroll::Infrastructure::Persistence::ActiveRecordExportReadRepository"
        bind "HrmPayroll::Domain::Repositories::ExportWriteRepositoryInterface", "HrmPayroll::Infrastructure::Persistence::ActiveRecordExportWriteRepository"
        catalogs = Array(Rails.application.config.x.hrm.permission_catalogs)
        Rails.application.config.x.hrm.permission_catalogs = catalogs | [ "HrmPayroll::Domain::ExportPermissionDefinitions" ]
        events = Rails.application.config.x.hrm.realtime_permissions || {}
        Rails.application.config.x.hrm.realtime_permissions = events.merge(
          "payroll_export." => %w[payroll.read payroll.exports.read],
          "payroll_export_access." => %w[payroll.read payroll.exports.read])
        bind "HrmPayroll::Domain::Repositories::ReadRepositoryInterface", "HrmPayroll::Infrastructure::Persistence::ActiveRecordReadRepository"
        bind "HrmPayroll::Domain::Repositories::WriteRepositoryInterface", "HrmPayroll::Infrastructure::Persistence::ActiveRecordWriteRepository"
      end
    end
  end
end
