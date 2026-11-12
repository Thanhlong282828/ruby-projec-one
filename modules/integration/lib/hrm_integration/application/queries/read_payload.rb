module HrmIntegration
  module Application
    module Queries
      class ReadPayload < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:)
          authorize!(actor, ::IntegrationWebhook, :index?)
          @repository.payload!(actor: actor, id: id)
        end
      end
    end
  end
end
