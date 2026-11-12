class DepartmentPolicy < ApplicationPolicy
  def index? = allowed?("departments.read")
  def show? = index?
  def create? = allowed?("departments.create")
  def update? = allowed?("departments.update")
  def destroy? = allowed?("departments.delete")
  class Scope < ApplicationPolicy::Scope
    def resolve = user&.allowed?("departments.read") ? tenant : scope.none
  end
end
