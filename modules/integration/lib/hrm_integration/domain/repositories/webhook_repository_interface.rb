module HrmIntegration
  module Domain
    module Repositories
      class WebhookRepositoryInterface
        def receive!(public_id:, timestamp:, event_id:, signature:, body:)
          raise NotImplementedError
        end
      end
    end
  end
end
