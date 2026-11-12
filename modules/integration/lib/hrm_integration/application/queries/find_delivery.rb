module HrmIntegration
  module Application
    module Queries
      class FindDelivery < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::OutboundReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, payload: false)
          authorize!(actor, ::IntegrationDelivery, :index?)
          @repository.find!(actor:, id:, payload:)
        end
      end
    end
  end
end
