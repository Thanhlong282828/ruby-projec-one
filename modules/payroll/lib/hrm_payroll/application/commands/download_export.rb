module HrmPayroll
  module Application
    module Commands
      class DownloadExport < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ExportWriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:)
          authorize!(actor, ::PayrollExport, :download?)
          @repository.download!(actor:, id:)
        end
      end
    end
  end
end
