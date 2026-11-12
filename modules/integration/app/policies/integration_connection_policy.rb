class IntegrationConnectionPolicy < ApplicationPolicy
  def index? = allowed?("integration.read")
  def show? = index?
  def create? = allowed?("integration.create")
  def update? = allowed?("integration.manage")
  class Scope < ApplicationPolicy::Scope
    def resolve = user&.allowed?("integration.read") ? tenant : scope.none
  end
end
