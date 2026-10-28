class Employee < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :department
  belongs_to :user, optional: true
  has_many :leave_requests, dependent: :restrict_with_error
  has_many :attendances, dependent: :restrict_with_error
  has_many :payslips, dependent: :restrict_with_error
  encrypts :bank_account
  encrypts :national_id
  enum :status, { active: "active", probation: "probation", inactive: "inactive" }, validate: true
  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :employee_code, :full_name, :email, :job_title, :hired_on, presence: true
  validates :employee_code, :email, uniqueness: { scope: :company_id }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :salary_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :annual_leave_days, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 365 }
  validates :user_id, uniqueness: true, allow_nil: true
  def public_attributes
    attributes.slice("id", "employee_code", "full_name", "email", "job_title", "department_id", "hired_on", "status", "lock_version")
  end
  before_validation { self.company_id ||= department&.company_id }
  validate { same_company_as(:department, :user) }

end
