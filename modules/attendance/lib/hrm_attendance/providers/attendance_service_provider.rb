module HrmAttendance
  module Providers
    class AttendanceServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmAttendance::Domain::Repositories::ReadRepositoryInterface", "HrmAttendance::Infrastructure::Persistence::ActiveRecordReadRepository"
        bind "HrmAttendance::Domain::Repositories::WriteRepositoryInterface", "HrmAttendance::Infrastructure::Persistence::ActiveRecordWriteRepository"
      end
    end
  end
end
