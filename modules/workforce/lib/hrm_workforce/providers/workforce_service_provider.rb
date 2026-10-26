module HrmWorkforce
  module Providers
    class WorkforceServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmWorkforce::Domain::Repositories::ReadRepositoryInterface", "HrmWorkforce::Infrastructure::Persistence::ActiveRecordReadRepository"
        bind "HrmWorkforce::Domain::Repositories::WriteRepositoryInterface", "HrmWorkforce::Infrastructure::Persistence::ActiveRecordWriteRepository"
      end
    end
  end
end
