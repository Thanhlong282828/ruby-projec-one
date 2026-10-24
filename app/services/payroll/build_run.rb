module Payroll
  class BuildRun
    def self.call(period:, actor:)
      raise Pundit::NotAuthorizedError unless actor&.active? && actor.staff?
      PayRun.transaction do
        run = PayRun.create!(period: period, created_by: actor)
        Employee.active.find_each do |employee|
          # VND stored in whole dong despite the generic *_cents storage names.
          run.payslips.create!(employee: employee, gross_cents: employee.salary_cents, deductions_cents: 0, net_cents: employee.salary_cents)
        end
        run
      end
    end
  end
end
