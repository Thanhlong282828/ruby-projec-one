module HrmIntegration
  module Application
    module Queries
      class OutboundWorkspace < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::OutboundReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, page: 1, status: nil)
          authorize!(actor, ::IntegrationDelivery, :index?)
          @repository.workspace(actor:, page:, status:)
        end
      end
    end
  end
end
