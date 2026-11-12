class WorkShiftPolicy < ApplicationPolicy
  def index? = allowed?("work_shifts.read")
  def show? = index?
  def create? = allowed?("work_shifts.create")
  def update? = allowed?("work_shifts.update")
  def destroy? = allowed?("work_shifts.delete")
  class Scope < ApplicationPolicy::Scope
    def resolve = user&.allowed?("work_shifts.read") ? tenant : scope.none
  end
end
