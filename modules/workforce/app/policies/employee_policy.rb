class EmployeePolicy < ApplicationPolicy
  def index? = allowed?("employees.read") || allowed?("employees.read_all")
  def show? = allowed?("employees.read_all") || (allowed?("employees.read") && record.user_id == user.id)
  def create? = allowed?("employees.create")
  def update? = allowed?("employees.update")
  def destroy? = allowed?("employees.delete")
  def sensitive? = allowed?("employees.sensitive")
  class Scope < Scope
    def resolve
      return tenant if user&.allowed?("employees.read_all")
      user&.allowed?("employees.read") ? tenant.where(user_id: user.id) : scope.none
    end
  end
end
