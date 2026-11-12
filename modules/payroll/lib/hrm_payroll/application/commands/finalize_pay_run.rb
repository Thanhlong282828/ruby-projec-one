# typed: strict

module HrmPayroll
  module Application
    module Commands
      class FinalizePayRun < Hrm::UseCase
        extend T::Sig

        sig { params(write: Domain::Repositories::WriteRepositoryInterface).void }
        # Container verifies string-based provider bindings at runtime; restore the static contract here.
        def initialize(write: T.cast(Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface), Domain::Repositories::WriteRepositoryInterface))
          super()
          @write = T.let(write, Domain::Repositories::WriteRepositoryInterface)
        end
        sig { params(run: PayRun, actor: T.nilable(User)).returns(PayRun) }
        def call(run:, actor:)
          authorize!(actor, run, :update?)
          actor = T.must(actor) # authorize! raises for nil before this narrowing.
          @write.finalize!(run: run, actor: actor) do |locked_run|
            raise TimeOff::Review::InvalidTransition, "Already finalized" unless locked_run.draft?
            raise TimeOff::Review::InvalidTransition, "Cannot finalize an empty payroll" unless @write.has_payslips?(run: locked_run)
          end
        end
      end
    end
  end
end
