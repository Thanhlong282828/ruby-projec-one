module HrmIntegration
  module Providers
    class IntegrationServiceProvider < Hrm::ServiceProvider
      def register
        bind "HrmIntegration::Domain::Repositories::PayrollBridgeRepositoryInterface", "HrmIntegration::Infrastructure::Persistence::ActiveRecordPayrollBridgeRepository"
        guards = Rails.application.config.x.hrm.realtime_guards || {}
        Rails.application.config.x.hrm.realtime_guards = guards.merge(
          "integration_delivery." => "HrmIntegration::Infrastructure::Persistence::DeliveryEventAuthorization",
          "integration_delivery_attempt." => "HrmIntegration::Infrastructure::Persistence::DeliveryEventAuthorization")
        bind "HrmIntegration::Domain::Repositories::AuditReadRepositoryInterface", "HrmIntegration::Infrastructure::Persistence::ActiveRecordAuditReadRepository"
        bind "HrmIntegration::Domain::Repositories::DeliveryRepositoryInterface", "HrmIntegration::Infrastructure::Persistence::ActiveRecordDeliveryRepository"
        bind "HrmIntegration::Domain::Repositories::OutboundWriteRepositoryInterface", "HrmIntegration::Infrastructure::Persistence::ActiveRecordOutboundWriteRepository"
        bind "HrmIntegration::Domain::Repositories::OutboundReadRepositoryInterface", "HrmIntegration::Infrastructure::Persistence::ActiveRecordOutboundReadRepository"
        bind "HrmIntegration::Domain::Repositories::ReadRepositoryInterface", "HrmIntegration::Infrastructure::Persistence::ActiveRecordReadRepository"
        bind "HrmIntegration::Domain::Repositories::WriteRepositoryInterface", "HrmIntegration::Infrastructure::Persistence::ActiveRecordWriteRepository"
        bind "HrmIntegration::Domain::Repositories::WebhookRepositoryInterface", "HrmIntegration::Infrastructure::Persistence::ActiveRecordWebhookRepository"
        event_permissions = Rails.application.config.x.hrm.realtime_permissions || {}
        Rails.application.config.x.hrm.realtime_permissions = event_permissions.merge(
          "integration_delivery." => "integration.read", "integration_delivery_attempt." => "integration.read",
          "integration_connection." => "integration.read", "integration_webhook." => "integration.read")
        catalogs = Array(Rails.application.config.x.hrm.permission_catalogs)
        Rails.application.config.x.hrm.permission_catalogs = catalogs | [ "HrmIntegration::Domain::PermissionDefinitions" ]
      end
    end
  end
end
