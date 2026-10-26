module HrmPlatform
  module Providers
    class PlatformServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmPlatform::Domain::Repositories::OutboxRepositoryInterface", "HrmPlatform::Infrastructure::Persistence::ActiveRecordOutboxRepository"
      end
    end
  end
end
