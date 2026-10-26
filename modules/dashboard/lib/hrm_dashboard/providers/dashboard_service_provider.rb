module HrmDashboard
  module Providers
    class DashboardServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmDashboard::Domain::Repositories::ReadRepositoryInterface", "HrmDashboard::Infrastructure::Persistence::ActiveRecordReadRepository"
      end
    end
  end
end
