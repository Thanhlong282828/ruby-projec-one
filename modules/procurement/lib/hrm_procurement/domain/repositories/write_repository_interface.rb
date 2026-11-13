module HrmProcurement
  module Domain
    module Repositories
      class WriteRepositoryInterface
        def create!(actor:, attributes:) = raise(NotImplementedError)
        def update!(actor:, id:, attributes:, lock_version:) = raise(NotImplementedError)
        def submit!(actor:, id:, lock_version:) = raise(NotImplementedError)
        def decide!(actor:, id:, decision:, reason:, lock_version:) = raise(NotImplementedError)
      end
    end
  end
end
