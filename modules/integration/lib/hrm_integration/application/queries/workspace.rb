module HrmIntegration
  module Application
    module Queries
      class Workspace < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, page: 1, status: nil)
          authorize!(actor, ::IntegrationConnection, :index?)
          @repository.workspace(actor: actor, page: page, status: status)
        end
      end
    end
  end
end
