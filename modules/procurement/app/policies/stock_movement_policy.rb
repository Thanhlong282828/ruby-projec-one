class StockMovementPolicy < ApplicationPolicy
  def index? = allowed?("inventory.balances.read")
  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.allowed?("inventory.balances.read") ? tenant.joins(:stock_receipt).where(stock_receipts: { status: "posted" }) : scope.none
    end
  end
end
