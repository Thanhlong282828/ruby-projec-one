class AuditLog < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true
  def readonly? = persisted?
end
