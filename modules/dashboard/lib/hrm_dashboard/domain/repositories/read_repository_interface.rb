module HrmDashboard
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def snapshot(actor:)
          raise NotImplementedError, "HrmDashboard::ReadRepositoryInterface##snapshot"
        end
      end
    end
  end
end
