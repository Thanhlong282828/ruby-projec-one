module HrmRecruitment
  module Providers
    class RecruitmentServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmRecruitment::Domain::Repositories::ReadRepositoryInterface", "HrmRecruitment::Infrastructure::Persistence::ActiveRecordReadRepository"
        bind "HrmRecruitment::Domain::Repositories::WriteRepositoryInterface", "HrmRecruitment::Infrastructure::Persistence::ActiveRecordWriteRepository"
      end
    end
  end
end
