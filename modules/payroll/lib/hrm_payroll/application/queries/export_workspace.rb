module HrmPayroll
  module Application
    module Queries
      class ExportWorkspace < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ExportReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, before: nil, period: nil)
          authorize!(actor, ::PayrollExport, :index?)
          @repository.workspace(actor:, before:, period:)
        end
      end
    end
  end
end
