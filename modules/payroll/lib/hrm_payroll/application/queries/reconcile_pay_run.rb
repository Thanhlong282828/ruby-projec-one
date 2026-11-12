# typed: strict

module HrmPayroll
  module Application
    module Queries
      class ReconcilePayRun < Hrm::UseCase
        extend T::Sig

        sig { params(repository: Domain::Repositories::ReadRepositoryInterface).void }
        # Container verifies string-based provider bindings at runtime; restore the static contract here.
        def initialize(repository: T.cast(Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface), Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = T.let(repository, Domain::Repositories::ReadRepositoryInterface)
        end
        sig { params(actor: T.nilable(User), run: PayRun).returns(Domain::ReconciliationResult) }
        def call(actor:, run:)
          authorize!(actor, run, :show?)
          actor = T.must(actor) # authorize! raises for nil before this narrowing.
          @repository.reconciliation(actor: actor, run: run)
        end
      end
    end
  end
end
