class AuditLogPolicy < ApplicationPolicy
  def index? = allowed?("audit.read")
  def show? = allowed?("audit.read")
  class Scope < ApplicationPolicy::Scope
    def resolve = user&.allowed?("audit.read") ? tenant : scope.none
  end
end
