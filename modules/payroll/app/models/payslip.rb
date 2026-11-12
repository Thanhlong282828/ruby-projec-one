class Payslip < ApplicationRecord
  include CompanyOwned
  belongs_to :pay_run
  belongs_to :employee
  before_validation :capture_employee_identity, on: :create
  validates :employee_code_snapshot, :employee_name_snapshot, presence: true, on: :create
  before_update { raise ActiveRecord::ReadOnlyRecord, "Payslips are immutable snapshots" }
  before_destroy { throw :abort }
  private def capture_employee_identity
    self.employee_code_snapshot = employee&.employee_code
    self.employee_name_snapshot = employee&.full_name
  end
  validates :gross_cents, :deductions_cents, :net_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :employee_id, uniqueness: { scope: :pay_run_id }
  validate { errors.add(:net_cents, "must equal gross minus deductions") if net_cents != gross_cents.to_i - deductions_cents.to_i }
  before_validation { self.company_id ||= pay_run&.company_id }
  validate { same_company_as(:pay_run, :employee) }
end
