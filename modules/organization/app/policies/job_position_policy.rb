class JobPositionPolicy < ApplicationPolicy
  def index? = allowed?("job_positions.read")
  def show? = index?
  def create? = allowed?("job_positions.create")
  def update? = allowed?("job_positions.update")
  def destroy? = allowed?("job_positions.delete")
  def export? = allowed?("job_positions.export")
  class Scope < ApplicationPolicy::Scope
    def resolve = user&.allowed?("job_positions.read") ? tenant : scope.none
  end
end
