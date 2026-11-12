module HrmIntegration
  module Application
    module Queries
      class FindConnection < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:)
          authorize!(actor, ::IntegrationConnection, :index?)
          @repository.connection!(actor: actor, id: id)
        end
      end
    end
  end
end
