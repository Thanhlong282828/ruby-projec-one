module HrmPayroll
  module Infrastructure
    module Persistence
      class ActiveRecordWriteRepository < Domain::Repositories::WriteRepositoryInterface
        def transaction(&block) = ::PayRun.transaction(&block)
        def create_run!(period:, actor:) = ::PayRun.create!(period: period, created_by: actor)
        def create_payslip!(run:, employee:)
          run.payslips.create!(employee: employee, gross_cents: employee.salary_cents, deductions_cents: 0, net_cents: employee.salary_cents)
        end
        def finalize!(run:)
          run.with_lock do
            yield
            run.update!(status: :finalized, finalized_at: Time.current)
          end
          run
        end
        def has_payslips?(run:) = run.payslips.exists?
      end
    end
  end
end
