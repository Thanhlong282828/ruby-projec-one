class Payslip < ApplicationRecord
  include CompanyOwned
  belongs_to :pay_run
  belongs_to :employee
  validates :gross_cents, :deductions_cents, :net_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :employee_id, uniqueness: { scope: :pay_run_id }
  validate { errors.add(:net_cents, "must equal gross minus deductions") if net_cents != gross_cents.to_i - deductions_cents.to_i }
  before_validation { self.company_id ||= pay_run&.company_id }
  validate { same_company_as(:pay_run, :employee) }

end
