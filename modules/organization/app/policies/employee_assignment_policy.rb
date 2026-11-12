class EmployeeAssignmentPolicy < ApplicationPolicy
  def index? = allowed?("employee_assignments.read")
  def show? = index?
  def create? = allowed?("employee_assignments.create")
  def update? = allowed?("employee_assignments.update")
  def destroy? = allowed?("employee_assignments.delete")
  def export? = allowed?("employee_assignments.export")
  class Scope < ApplicationPolicy::Scope
    def resolve = user&.allowed?("employee_assignments.read") ? tenant : scope.none
  end
end
