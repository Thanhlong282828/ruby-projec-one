class EmployeePolicy < ApplicationPolicy
  def index? = user.present?
  def show? = user&.staff? || record.user_id == user&.id
  class Scope < Scope
    def resolve = user&.staff? ? scope.all : scope.where(user_id: user&.id)
  end
end
