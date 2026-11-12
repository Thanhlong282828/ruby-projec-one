class OnboardingCasePolicy < ApplicationPolicy
  def index? = allowed?("onboarding.read") || allowed?("onboarding.read_all")
  def show? = allowed?("onboarding.read_all") || (allowed?("onboarding.read") && record.employee.user_id == user.id)
  def create? = allowed?("onboarding.create")
  def update? = allowed?("onboarding.manage")
  class Scope < ApplicationPolicy::Scope
    def resolve
      return tenant if user&.allowed?("onboarding.read_all")
      user&.allowed?("onboarding.read") ? tenant.joins(:employee).where(employees: { user_id: user.id }) : scope.none
    end
  end
end
