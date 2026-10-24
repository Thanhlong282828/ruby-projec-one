Rails.application.config.active_job.queue_adapter = :sidekiq
Rails.application.config.cache_store = :redis_cache_store, { url: ENV.fetch("CACHE_REDIS_URL", "redis://redis:6379/1"), namespace: "hrm" }
Rails.application.config.active_record.encryption.primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY")
Rails.application.config.active_record.encryption.deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY")
Rails.application.config.active_record.encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT")
Rails.application.config.action_mailer.delivery_method = :smtp
Rails.application.config.action_mailer.smtp_settings = { address: ENV.fetch("SMTP_HOST", "mailpit"), port: ENV.fetch("SMTP_PORT", 1025).to_i }
if ENV["SMTP_USERNAME"].present?
  Rails.application.config.action_mailer.smtp_settings.merge!(
    user_name: ENV.fetch("SMTP_USERNAME"), password: ENV.fetch("SMTP_PASSWORD"),
    authentication: :plain, enable_starttls_auto: true
  )
end
Rails.application.config.action_mailer.raise_delivery_errors = true
Rails.application.config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "localhost:3100") }
Rails.application.config.filter_parameters += [:password, :token, :authorization, :bank_account, :national_id, :salary_cents]
