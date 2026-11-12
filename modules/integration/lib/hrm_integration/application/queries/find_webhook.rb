module HrmIntegration
  module Application
    module Queries
      class FindWebhook < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:)
          authorize!(actor, ::IntegrationWebhook, :index?)
          @repository.webhook!(actor: actor, id: id)
        end
      end
    end
  end
end
