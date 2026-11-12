module HrmOnboarding
  module Domain
    module Repositories
      class WriteRepositoryInterface
        def create!(actor:, attributes:)
          raise NotImplementedError
        end
        def transition!(actor:, id:, status:, lock_version:)
          raise NotImplementedError
        end
        def complete!(actor:, id:, code:, lock_version:)
          raise NotImplementedError
        end
      end
    end
  end
end
