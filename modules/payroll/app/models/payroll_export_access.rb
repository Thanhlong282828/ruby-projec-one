class PayrollExportAccess < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :payroll_export
  belongs_to :actor, class_name: "User"
  validates :result, inclusion: { in: %w[allowed integrity_failed] }
  validate { same_company_as(:payroll_export, :actor) }
  def readonly? = persisted?
  def public_attributes = attributes.slice("id", "actor_id", "result", "created_at")
end
