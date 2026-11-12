module HrmAttendance
  module Providers
    class AttendanceServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmAttendance::Domain::Repositories::ScheduleReadRepositoryInterface", "HrmAttendance::Infrastructure::Persistence::ActiveRecordScheduleReadRepository"
        bind "HrmAttendance::Domain::Repositories::ScheduleWriteRepositoryInterface", "HrmAttendance::Infrastructure::Persistence::ActiveRecordScheduleWriteRepository"
        catalogs = Array(Rails.application.config.x.hrm.permission_catalogs)
        Rails.application.config.x.hrm.permission_catalogs = catalogs | [ "HrmAttendance::Domain::PermissionDefinitions", "HrmAttendance::Domain::SchedulePermissionDefinitions" ]
        bind "HrmAttendance::Domain::Repositories::ShiftReadRepositoryInterface", "HrmAttendance::Infrastructure::Persistence::ActiveRecordShiftReadRepository"
        bind "HrmAttendance::Domain::Repositories::ShiftWriteRepositoryInterface", "HrmAttendance::Infrastructure::Persistence::ActiveRecordShiftWriteRepository"
        bind "HrmAttendance::Domain::Repositories::ReadRepositoryInterface", "HrmAttendance::Infrastructure::Persistence::ActiveRecordReadRepository"
        bind "HrmAttendance::Domain::Repositories::WriteRepositoryInterface", "HrmAttendance::Infrastructure::Persistence::ActiveRecordWriteRepository"
      end
    end
  end
end
