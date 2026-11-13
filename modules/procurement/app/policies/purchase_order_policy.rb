class PurchaseOrderPolicy < ApplicationPolicy
  def index? = allowed?("procurement.orders.read")
  def show? = index?
  def create? = index? && allowed?("procurement.orders.create")
  def update_any? = index? && allowed?("procurement.orders.update")
  def issue_any? = index? && allowed?("procurement.orders.issue")
  def update? = update_any? && record.status == "draft"
  def issue? = issue_any? && record.status == "draft"
  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.allowed?("procurement.orders.read") ? tenant : scope.none
    end
  end
end
