# typed: strict

module HrmPayroll
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        extend T::Sig
        sig { params(actor: User, page: T.nilable(T.any(Integer, String)), status: T.nilable(String), period: T.nilable(Date), recent: T::Boolean).returns(T::Array[PayRun]) }
        # Pundit/Pagination are dynamic boundaries; constrain the scope and materialized models.
        def list(actor:, page: 1, status: nil, period: nil, recent: false)
          scope = filtered(actor: actor, status: status, period: period).order(period: :desc, id: :desc)
          T.cast(recent ? scope.limit(5).to_a : Hrm::Pagination.call(scope, page).to_a, T::Array[PayRun])
        end
        sig { params(actor: User, status: T.nilable(String), period: T.nilable(Date)).returns(Integer) }
        def count(actor:, status: nil, period: nil) = filtered(actor: actor, status: status, period: period).count
        sig { params(actor: User, status: T.nilable(String), period: T.nilable(Date)).returns(ActiveRecord::Relation) }
        def filtered(actor:, status:, period:)
          # Pundit returns a dynamic scope; the scope owns PayRun records.
          scope = T.cast(Pundit.policy_scope!(actor, ::PayRun), ActiveRecord::Relation)
          scope = scope.where(status: status) if status
          scope = scope.where(period: period) if period
          scope
        end
        private :filtered
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
