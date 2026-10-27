module HrmPlatform
  module Domain
    module Repositories
      class OutboxRepositoryInterface
        def append!(event_type:, payload:)
          raise NotImplementedError, "HrmPlatform::OutboxRepositoryInterface##append!"
        end
        def pending(limit: 100)
          raise NotImplementedError, "HrmPlatform::OutboxRepositoryInterface##pending"
        end
        def deliver(event:, &block)
          raise NotImplementedError, "HrmPlatform::OutboxRepositoryInterface##deliver"
        end
      end
    end
  end
end
