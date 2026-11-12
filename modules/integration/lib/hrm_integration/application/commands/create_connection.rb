module HrmIntegration
  module Application
    module Commands
      class CreateConnection < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, attributes:)
          authorize!(actor, ::IntegrationConnection, :create?)
          @repository.create!(actor: actor, attributes: attributes)
        end
      end
    end
  end
end
