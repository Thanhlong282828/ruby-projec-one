module HrmPayroll
  module Application
    module Queries
      class FindExport < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ExportReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:)
          authorize!(actor, ::PayrollExport, :show?)
          @repository.find!(actor:, id:)
        end
      end
    end
  end
end
