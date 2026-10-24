Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch("CACHE_REDIS_URL", "redis://redis:6379/1"), namespace: "throttle")
Rack::Attack.throttle("login/ip", limit: 10, period: 60) do |request|
  request.ip if request.post? && ["/session", "/api/v1/session"].include?(request.path)
end
Rails.application.config.middleware.use Rack::Attack
