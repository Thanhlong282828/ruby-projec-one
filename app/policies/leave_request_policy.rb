class LeaveRequestPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = user&.staff? || user&.manager? || record.employee.user_id == user&.id
  def create? = user&.staff? || record.employee.user_id == user&.id
  def approve? = (user&.staff? || user&.manager?) && record.employee.user_id != user&.id
  def reject? = approve?
  class Scope < Scope
    def resolve
      return scope.all if user&.staff? || user&.manager?
      scope.joins(:employee).where(employees: { user_id: user&.id })
    end
  end
end
