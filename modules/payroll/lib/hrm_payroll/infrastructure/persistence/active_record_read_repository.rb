# typed: strict

module HrmPayroll
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        extend T::Sig
        sig { params(actor: User, page: T.nilable(T.any(Integer, String))).returns(T::Array[PayRun]) }
        # Pundit/Pagination dynamically return scopes; cast only their materialized results.
        def list(actor:, page: 1) = T.cast(Hrm::Pagination.call(Pundit.policy_scope!(actor, ::PayRun).order(period: :desc), page).to_a, T::Array[PayRun])
        sig { params(actor: User, id: T.nilable(T.any(Integer, String))).returns(PayRun) }
        def find!(actor:, id:) = T.cast(Pundit.policy_scope!(actor, ::PayRun).find(id), PayRun)
        sig { params(actor: User, run: PayRun).returns(T::Array[Payslip]) }
        def payslips(actor:, run:)
          ActiveRecord::Base.uncached do
            source = find!(actor: actor, id: run.id)
            Pundit.authorize(actor, source, :show?)
            source.payslips.where(company_id: actor.company_id).order(:id).to_a
          end
        end
        sig { params(actor: User, run: PayRun).returns(HrmPayroll::Domain::ReconciliationResult) }
        def reconciliation(actor:, run:)
          # Long-lived query caches must not preserve revoked source grants.
          ActiveRecord::Base.uncached do
            source = find!(actor: actor, id: run.id)
            Pundit.authorize(actor, source, :show?)
            visible = actor.allowed?("attendance.read_all") && actor.allowed?("leave.read_all")
            # ActiveRecord JSON deserialization is untyped in generated RBI. New snapshots
            # are written by typed PayrollReconciliation; old runs legitimately store NULL.
            stored = visible ? T.cast(source.reconciliation_snapshot, T.nilable(Domain::Snapshot)) : nil
            { source_visible: visible, finalized: source.finalized?, captured: stored,
             current: visible && source.draft? ? PayrollReconciliation.capture(run: source) : nil }
          end
        end
      end
    end
  end
end
