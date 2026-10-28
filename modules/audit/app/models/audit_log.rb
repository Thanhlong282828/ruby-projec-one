class AuditLog < ApplicationRecord
  include CompanyOwned
  belongs_to :actor, class_name: "User", optional: true
  def readonly? = persisted?
  before_validation { self.company_id ||= actor&.company_id }
  validate { same_company_as(:actor) }

end
