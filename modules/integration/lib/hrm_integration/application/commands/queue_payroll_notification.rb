module HrmIntegration
  module Application
    module Commands
      class QueuePayrollNotification < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::PayrollBridgeRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, export_id:, connection_id:, target_key:)
          authorize!(actor, ::IntegrationDelivery, :create?)
          authorize!(actor, ::PayrollExport, :notify?)
          @repository.enqueue!(actor:, export_id:, connection_id:, target_key:)
        end
      end
    end
  end
end
