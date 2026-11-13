class StockReturnReversalPolicy < ApplicationPolicy
  def index? = allowed?("inventory.return_reversals.read")
  def show? = index?
  def create? = index? && allowed?("inventory.return_reversals.post") && allowed?("inventory.returns.read")
  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.allowed?("inventory.return_reversals.read") ? tenant.where(status: "posted") : scope.none
    end
  end
end
