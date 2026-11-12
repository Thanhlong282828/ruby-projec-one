class IntegrationWebhookPolicy < ApplicationPolicy
  def index? = allowed?("integration.read")
  def show? = index?
  def update? = allowed?("integration.review")
  def payload? = allowed?("integration.payload.read")
  class Scope < ApplicationPolicy::Scope
    def resolve = user&.allowed?("integration.read") ? tenant : scope.none
  end
end
