module HrmTimeOff
  module Providers
    class TimeOffServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmTimeOff::Domain::Repositories::ReadRepositoryInterface", "HrmTimeOff::Infrastructure::Persistence::ActiveRecordReadRepository"
        bind "HrmTimeOff::Domain::Repositories::WriteRepositoryInterface", "HrmTimeOff::Infrastructure::Persistence::ActiveRecordWriteRepository"
      end
    end
  end
end
