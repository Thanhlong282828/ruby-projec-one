module HrmIntegration
  module Application
    module Commands
      class ReviewWebhook < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, decision:, note: nil, lock_version:)
          authorize!(actor, ::IntegrationWebhook, :update?)
          @repository.review!(actor: actor, id: id, decision: decision, note: note, lock_version: lock_version)
        end
      end
    end
  end
end
