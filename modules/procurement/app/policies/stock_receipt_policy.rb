class StockReceiptPolicy < ApplicationPolicy
  def index? = allowed?("inventory.receipts.read")
  def show? = index?
  def create? = index? && allowed?("inventory.receipts.post") && allowed?("procurement.receipts.read")
  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.allowed?("inventory.receipts.read") ? tenant.where(status: "posted") : scope.none
    end
  end
end
