ActiveSupport::Notifications.subscribe("record.changed.hrm") do |event|
  Rails.logger.info({ event: event.name, record_type: event.payload[:record_type], record_id: event.payload[:record_id] }.to_json)
end
