module HrmIntegration
  module Application
    module Commands
      class RetryDelivery < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::OutboundWriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, lock_version:)
          authorize!(actor, ::IntegrationDelivery, :retry?)
          @repository.retry!(actor:, id:, lock_version:)
        end
      end
    end
  end
end
