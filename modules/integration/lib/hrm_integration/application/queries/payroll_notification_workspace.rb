module HrmIntegration
  module Application
    module Queries
      class PayrollNotificationWorkspace < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::OutboundReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, export_id:)
          authorize!(actor, ::IntegrationDelivery, :create?)
          authorize!(actor, ::PayrollExport, :notify?)
          @repository.payroll_workspace(actor:, export_id:)
        end
      end
    end
  end
end
