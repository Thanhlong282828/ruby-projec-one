class EmployeeShiftAssignmentPolicy < ApplicationPolicy
  def index? = allowed?("shift_assignments.read") || allowed?("shift_assignments.read_all")
  def create? = allowed?("shift_assignments.create")
  def update? = allowed?("shift_assignments.update")
  def destroy? = allowed?("shift_assignments.delete")
  class Scope < ApplicationPolicy::Scope
    def resolve
      return tenant if user&.allowed?("shift_assignments.read_all")
      user&.allowed?("shift_assignments.read") ? tenant.joins(:employee).where(employees: { user_id: user.id }) : scope.none
    end
  end
end
