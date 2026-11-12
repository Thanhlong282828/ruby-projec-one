class CostCenterPolicy < ApplicationPolicy
  def index? = allowed?("cost_centers.read")
  def show? = index?
  def create? = allowed?("cost_centers.create")
  def update? = allowed?("cost_centers.update")
  def destroy? = allowed?("cost_centers.delete")
  def export? = allowed?("cost_centers.export")
  class Scope < ApplicationPolicy::Scope
    def resolve = user&.allowed?("cost_centers.read") ? tenant : scope.none
  end
end
