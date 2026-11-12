class OrganizationUnitPolicy < ApplicationPolicy
  def index? = allowed?("organization_units.read")
  def show? = index?
  def create? = allowed?("organization_units.create")
  def update? = allowed?("organization_units.update")
  def destroy? = allowed?("organization_units.delete")
  def export? = allowed?("organization_units.export")
  class Scope < ApplicationPolicy::Scope
    def resolve = user&.allowed?("organization_units.read") ? tenant : scope.none
  end
end
