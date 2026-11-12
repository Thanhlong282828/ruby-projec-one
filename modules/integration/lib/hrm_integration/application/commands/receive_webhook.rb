module HrmIntegration
  module Application
    module Commands
      # Machine entrypoint: never authenticate by browser cookie or caller-supplied company.
      class ReceiveWebhook
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WebhookRepositoryInterface))
          @repository = repository
        end
        def call(public_id:, timestamp:, event_id:, signature:, body:)
          @repository.receive!(public_id: public_id, timestamp: timestamp, event_id: event_id, signature: signature, body: body)
        end
      end
    end
  end
end
