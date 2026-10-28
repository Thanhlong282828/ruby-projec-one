module HrmIdentity
  module Providers
    class IdentityServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmIdentity::Domain::Repositories::AdministrationRepositoryInterface", "HrmIdentity::Infrastructure::Persistence::ActiveRecordAdministrationRepository"
        bind "HrmIdentity::Domain::Repositories::ReadRepositoryInterface", "HrmIdentity::Infrastructure::Persistence::ActiveRecordReadRepository"
        bind "HrmIdentity::Domain::Repositories::WriteRepositoryInterface", "HrmIdentity::Infrastructure::Persistence::ActiveRecordWriteRepository"
      end
    end
  end
end
