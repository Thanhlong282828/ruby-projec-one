module HrmPayroll
  module Application
    module Commands
      class CreateExport < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ExportWriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, pay_run_id:)
          authorize!(actor, ::PayrollExport, :create?)
          @repository.create!(actor:, pay_run_id:)
        end
      end
    end
  end
end
