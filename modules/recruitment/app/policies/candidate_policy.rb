class CandidatePolicy < ApplicationPolicy
  def index? = allowed?("recruitment.read")
  def show? = allowed?("recruitment.read")
  def create? = allowed?("recruitment.write")
  def update? = allowed?("recruitment.write")
  class Scope < ApplicationPolicy::Scope
    def resolve = user&.allowed?("recruitment.read") ? tenant : scope.none
  end
end
