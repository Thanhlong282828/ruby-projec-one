module HrmIntegration
  module Domain
    module Repositories
      class WriteRepositoryInterface
        def create!(actor:, attributes:)
          raise NotImplementedError
        end
        def change_status!(actor:, id:, active:, lock_version:)
          raise NotImplementedError
        end
        def rotate!(actor:, id:, lock_version:)
          raise NotImplementedError
        end
        def review!(actor:, id:, decision:, note:, lock_version:)
          raise NotImplementedError
        end
      end
    end
  end
end
