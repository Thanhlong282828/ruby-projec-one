class AttendancePolicy < ApplicationPolicy
  def index? = user.present?
  def create? = record.employee.user_id == user&.id
  def checkout? = record.employee.user_id == user&.id
  class Scope < Scope
    def resolve = user&.staff? ? scope.all : scope.joins(:employee).where(employees: { user_id: user&.id })
  end
end
