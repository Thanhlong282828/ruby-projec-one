module HrmTimeOff
  module Application
    module Queries
      # Trusted scheduler query; no HTTP endpoint exposes this organization-wide data.
      class DailySummary
        def initialize(identity: Hrm::Container.resolve(HrmIdentity::Domain::Repositories::ReadRepositoryInterface), leaves: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @identity, @leaves = identity, leaves
        end
        def call = { recipients: @identity.summary_recipients, pending: @leaves.pending_count }
      end
    end
  end
end
