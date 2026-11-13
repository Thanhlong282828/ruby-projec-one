class InventoryCatalogPolicy < ApplicationPolicy
  def index? = allowed?("inventory.catalog.read")
  def show? = index?
  def create? = index? && allowed?("inventory.catalog.manage")
  def update? = create?
  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.allowed?("inventory.catalog.read") ? tenant : scope.none
    end
  end
end
