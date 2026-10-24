module Hrm
  class RecordObserver
    def self.record(record, action)
      # Runs inside the model transaction: audit + outbox are committed together.
      metadata = { changed_fields: record.saved_changes.keys - %w[bank_account national_id salary_cents password_digest] }
      AuditLog.create!(actor: Current.user, action: action, record_type: record.class.name, record_id: record.id, metadata: metadata)
      OutboxEvent.create!(event_type: "#{record.model_name.singular}.#{action}", payload: { record_id: record.id, record_type: record.class.name })
    end
    def self.committed(record)
      ActiveSupport::Notifications.instrument("record.changed.hrm", record_type: record.class.name, record_id: record.id)
      Rails.cache.delete("dashboard/stats")
    rescue StandardError => error
      # Cache availability must never undo or misreport a committed DB write.
      Rails.logger.warn("Cache invalidation failed: #{error.class}")
    end
  end
end
