module HrmIntegration
  module Application
    module Commands
      class QueueDelivery < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::OutboundWriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, connection_id:, target_key:, body:, idempotency_key:)
          authorize!(actor, ::IntegrationDelivery, :create?)
          @repository.enqueue!(actor:, connection_id:, target_key:, body:, idempotency_key:)
        end
      end
    end
  end
end
