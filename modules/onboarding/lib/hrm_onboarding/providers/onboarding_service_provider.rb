module HrmOnboarding
  module Providers
    class OnboardingServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmOnboarding::Domain::Repositories::ReadRepositoryInterface", "HrmOnboarding::Infrastructure::Persistence::ActiveRecordReadRepository"
        bind "HrmOnboarding::Domain::Repositories::WriteRepositoryInterface", "HrmOnboarding::Infrastructure::Persistence::ActiveRecordWriteRepository"
        catalogs = Array(Rails.application.config.x.hrm.permission_catalogs)
        Rails.application.config.x.hrm.permission_catalogs = catalogs | [ "HrmOnboarding::Domain::PermissionDefinitions" ]
      end
    end
  end
end
