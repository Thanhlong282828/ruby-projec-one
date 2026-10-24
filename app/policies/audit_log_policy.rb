class AuditLogPolicy < ApplicationPolicy
  def index? = user&.admin?
end
