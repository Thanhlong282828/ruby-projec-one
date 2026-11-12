# typed: strict

module HrmPayroll
  module Infrastructure
    module Persistence
      class ActiveRecordWriteRepository < Domain::Repositories::WriteRepositoryInterface
        extend T::Sig
        sig { type_parameters(:Result).params(actor: User, block: T.proc.returns(T.type_parameter(:Result))).returns(T.nilable(T.type_parameter(:Result))) }
        def transaction(actor:, &block)
          ::PayRun.transaction do
            ActiveRecord::Base.uncached do
              Pundit.authorize(actor, ::PayRun, :create?)
              Current.set(user: actor) { yield }
            end
          end
        end
        sig { params(period: T.nilable(T.any(Date, String)), actor: User).returns(PayRun) }
        def create_run!(period:, actor:) = ::PayRun.create!(period: period, created_by: actor)
        sig { params(run: PayRun, employee: Employee).returns(Payslip) }
        def create_payslip!(run:, employee:)
          run.payslips.create!(employee: employee, gross_cents: employee.salary_cents, deductions_cents: 0, net_cents: employee.salary_cents)
        end
        sig { params(run: PayRun, actor: User, block: T.proc.params(run: PayRun).void).returns(PayRun) }
        def finalize!(run:, actor:, &block)
          source = ::PayRun.where(company_id: actor.company_id).find(run.id)
          source.with_lock do
            ActiveRecord::Base.uncached do
              Pundit.authorize(actor, source, :update?)
              yield source
              ::Employee.where(company_id: actor.company_id, id: source.payslips.select(:employee_id)).order(:id).lock.load
              snapshot = PayrollReconciliation.capture(run: source, lock: true)
              raise TimeOff::Review::InvalidTransition, "Phiếu lương thiếu định danh tại lúc tạo hoặc số tiền không hợp lệ." if snapshot.fetch("invalid_payslip_count").positive?
              # Open attendance/pending leave remain recorded warnings, not a new closing policy.
              Current.set(user: actor) { source.update!(status: :finalized, finalized_at: Time.current, reconciliation_snapshot: snapshot) }
            end
          end
          source
        end
        sig { params(run: PayRun).returns(T::Boolean) }
        def has_payslips?(run:) = run.payslips.exists?
      end
    end
  end
end
