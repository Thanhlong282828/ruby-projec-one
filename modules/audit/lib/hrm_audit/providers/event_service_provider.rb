module HrmAudit
  module Providers
    class EventServiceProvider
      def self.boot(app: Rails.application)
        old = app.config.x.hrm.audit_subscription
        ActiveSupport::Notifications.unsubscribe(old) if old
        app.config.x.hrm.audit_subscription = ActiveSupport::Notifications.subscribe("record.changed.hrm") do |event|
          Rails.logger.info({ event: event.name, record_type: event.payload[:record_type], record_id: event.payload[:record_id] }.to_json)
        end
      end
    end
  end
end
