class IntegrationDeliveryPolicy < ApplicationPolicy
  def index? = allowed?("integration.read")
  def source_read?
    record.is_a?(Class) || record.payroll_export_id.nil? || Pundit.policy!(user, ::PayrollExport).index?
  end
  def source_notify?
    record.is_a?(Class) || record.payroll_export_id.nil? || Pundit.policy!(user, ::PayrollExport).notify?
  end
  def show? = index? && source_read?
  def create? = allowed?("integration.send") && index? && source_notify?
  def retry? = allowed?("integration.retry") && create?
  def payload? = allowed?("integration.payload.read") && index? && source_read?
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.allowed?("integration.read")
      Pundit.policy!(user, ::PayrollExport).index? ? tenant : tenant.where(payroll_export_id: nil)
    end
  end
end
