class PayRun < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :created_by, class_name: "User"
  has_one :payroll_export, dependent: :restrict_with_error
  has_many :payslips, dependent: :restrict_with_error
  enum :status, { draft: "draft", finalized: "finalized" }, validate: true
  validates :period, presence: true, uniqueness: { scope: :company_id }
  before_validation { self.period = period.beginning_of_month if period }
  before_validation { self.company_id ||= created_by&.company_id }
  validate { same_company_as(:created_by) }
  validate do
    if persisted? && (will_save_change_to_company_id? || will_save_change_to_created_by_id? || will_save_change_to_period?)
      errors.add(:base, "Payroll source identity is immutable")
    end
  end
  before_update { raise ActiveRecord::ReadOnlyRecord, "Finalized payroll is immutable" if status_in_database == "finalized" }
end
