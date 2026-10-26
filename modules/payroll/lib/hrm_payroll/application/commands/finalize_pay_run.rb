module HrmPayroll
  module Application
    module Commands
      class FinalizePayRun < Hrm::UseCase
        def initialize(write: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          @write = write
        end
        def call(run:, actor:)
          authorize!(actor, run, :update?)
          @write.finalize!(run: run) do
            raise TimeOff::Review::InvalidTransition, "Already finalized" unless run.draft?
            raise TimeOff::Review::InvalidTransition, "Cannot finalize an empty payroll" unless @write.has_payslips?(run: run)
          end
        end
      end
    end
  end
end
