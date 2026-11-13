class ProcurementSupplierPolicy < ApplicationPolicy
  def index? = allowed?("procurement.suppliers.read")
  def show? = index?
  def create? = index? && allowed?("procurement.suppliers.create")
  def update? = index? && allowed?("procurement.suppliers.update")
  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.allowed?("procurement.suppliers.read") ? tenant : scope.none
    end
  end
end
