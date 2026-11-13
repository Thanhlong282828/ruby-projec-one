class StockReturnPolicy < ApplicationPolicy
  def index? = allowed?("inventory.returns.read")
  def show? = index?
  def create? = index? && allowed?("inventory.returns.post") && allowed?("inventory.receipts.read")
  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.allowed?("inventory.returns.read") ? tenant.where(status: "posted") : scope.none
    end
  end
end
