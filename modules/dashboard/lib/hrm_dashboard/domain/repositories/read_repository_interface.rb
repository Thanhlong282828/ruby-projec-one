module HrmDashboard
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def snapshot(actor:, period:)
          raise NotImplementedError, "HrmDashboard::ReadRepositoryInterface##snapshot"
        end
      end
    end
  end
end
