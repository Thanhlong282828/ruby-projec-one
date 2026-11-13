class GoodsReceiptPolicy < ApplicationPolicy
  def index? = allowed?("procurement.receipts.read")
  def show? = index?
  def create? = index? && allowed?("procurement.receipts.create") && allowed?("procurement.orders.read")
  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.allowed?("procurement.receipts.read") ? tenant.where(status: "recorded") : scope.none
    end
  end
end
