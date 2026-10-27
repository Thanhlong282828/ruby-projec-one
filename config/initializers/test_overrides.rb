if Rails.env.test?
  Rails.application.config.cache_store = :memory_store
  Rails.cache = ActiveSupport::Cache::MemoryStore.new
  Rails.application.config.action_mailer.delivery_method = :test
  Rails.application.config.active_job.queue_adapter = :test
  Rack::Attack.enabled = false
end
