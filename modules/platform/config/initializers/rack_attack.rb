Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch("CACHE_REDIS_URL", "redis://redis:6379/1"), namespace: "throttle")
Rack::Attack.throttle("login/ip", limit: 10, period: 60) do |request|
  request.ip if request.post? && ["/session", "/api/v1/session"].include?(request.path)
end
Rails.application.config.middleware.use Rack::Attack

# Đoạn code Ruby on Rails này đang cấu hình Rate Limiting (giới hạn số lần gửi request) bằng thư viện Rack::Attack,
#  nhằm chống spam đăng nhập và giảm nguy cơ tấn công Brute Force.
#  Cụ thể: Mỗi địa chỉ IP chỉ được gửi tối đa 10 request đăng nhập trong 60 giây tới hai endpoint được chỉ định.
