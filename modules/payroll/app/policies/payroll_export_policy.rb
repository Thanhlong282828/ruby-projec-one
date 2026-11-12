class PayrollExportPolicy < ApplicationPolicy
  def index? = allowed?("payroll.read") && allowed?("payroll.exports.read")
  def show? = index?
  def create? = index? && allowed?("payroll.exports.create")
  def notify? = index? && allowed?("payroll.exports.notify")
  def download? = index? && allowed?("payroll.exports.download")
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.allowed?("payroll.read") && user.allowed?("payroll.exports.read")
      tenant
    end
  end
end
