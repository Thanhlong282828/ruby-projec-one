module HrmTimeOff
  module Domain
    module Repositories
      class WriteRepositoryInterface
        def build(employee:, attributes:)
          raise NotImplementedError, "HrmTimeOff::WriteRepositoryInterface##build"
        end
        def create!(employee:, attributes:)
          raise NotImplementedError, "HrmTimeOff::WriteRepositoryInterface##create!"
        end
        def with_review_lock(request:, &block)
          raise NotImplementedError, "HrmTimeOff::WriteRepositoryInterface##with_review_lock"
        end
        def review!(request:, reviewer:, decision:)
          raise NotImplementedError, "HrmTimeOff::WriteRepositoryInterface##review!"
        end
      end
    end
  end
end
