class LeaveRequestPolicy < ApplicationPolicy
  def index? = allowed?("leave.read") || allowed?("leave.read_all")
  def show? = allowed?("leave.read_all") || (allowed?("leave.read") && record.employee.user_id == user.id)
  def create? = allowed?("leave.submit_for_others") || (allowed?("leave.submit") && record.employee.user_id == user.id)
  def approve? = allowed?("leave.review") && record.employee.user_id != user.id
  def reject? = approve?
  class Scope < Scope
    def resolve
      return tenant if user&.allowed?("leave.read_all")
      user&.allowed?("leave.read") ? tenant.joins(:employee).where(employees: { user_id: user.id }) : scope.none
    end
  end
end
