module HrmPayroll
  module Providers
    class PayrollServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmPayroll::Domain::Repositories::ReadRepositoryInterface", "HrmPayroll::Infrastructure::Persistence::ActiveRecordReadRepository"
        bind "HrmPayroll::Domain::Repositories::WriteRepositoryInterface", "HrmPayroll::Infrastructure::Persistence::ActiveRecordWriteRepository"
      end
    end
  end
end
