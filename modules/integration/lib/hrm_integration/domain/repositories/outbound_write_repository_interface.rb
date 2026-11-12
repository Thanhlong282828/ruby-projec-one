module HrmIntegration
  module Domain
    module Repositories
      class OutboundWriteRepositoryInterface
        def enqueue!(actor:, connection_id:, target_key:, body:, idempotency_key:)
          raise NotImplementedError
        end
        def retry!(actor:, id:, lock_version:)
          raise NotImplementedError
        end
      end
    end
  end
end
