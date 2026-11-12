class SystemAuditLog < ApplicationRecord
  belongs_to :principal_user, class_name: "User"
  belongs_to :company
  def readonly? = persisted?
end
