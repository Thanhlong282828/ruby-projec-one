class AttendancePolicy < ApplicationPolicy
  def index? = allowed?("attendance.read") || allowed?("attendance.read_all")
  def create? = allowed?("attendance.clock") && record.employee.user_id == user.id
  def checkout? = create?
  class Scope < Scope
    def resolve
      return tenant if user&.allowed?("attendance.read_all")
      user&.allowed?("attendance.read") ? tenant.joins(:employee).where(employees: { user_id: user.id }) : scope.none
    end
  end
end
