module Integration
  class AuditLogPolicy < ApplicationPolicy
    def index? = allowed?("integration.read") && allowed?("integration.audit.read")
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless user&.allowed?("integration.read") && user.allowed?("integration.audit.read")
        rows = tenant.where(record_type: HrmIntegration::Domain::Services::AuditFilters::RESOURCES.values)
        return rows if Pundit.policy!(user, ::PayrollExport).index?
        deliveries = Pundit.policy_scope!(user, ::IntegrationDelivery).select(:id)
        attempts = ::IntegrationDeliveryAttempt.where(company_id: user.company_id, integration_delivery_id: deliveries).select(:id)
        rows.where.not(record_type: %w[IntegrationDelivery IntegrationDeliveryAttempt])
          .or(rows.where(record_type: "IntegrationDelivery", record_id: deliveries))
          .or(rows.where(record_type: "IntegrationDeliveryAttempt", record_id: attempts))
      end
    end
  end
end
