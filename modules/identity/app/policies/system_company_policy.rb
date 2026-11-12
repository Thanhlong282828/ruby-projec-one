class SystemCompanyPolicy < ApplicationPolicy
  def index? = user&.allowed?("system.companies.read")
  def create? = index? && user.allowed?("system.companies.manage")
  def update? = create?
end
