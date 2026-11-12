# Normalize format suffixes and escaped path characters before matching login routes.
login_request = lambda do |request|
  path = Rack::Utils.unescape_path(request.path).squeeze('/')
  request.post? && %r{\A/(?:api/v1/)?session(?:\.[^/]+)?/?\z}.match?(path)
end
Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch("CACHE_REDIS_URL", "redis://redis:6379/1"), namespace: "throttle")
Rack::Attack.throttle("login/ip", limit: 10, period: 60) do |request|
  request.ip if login_request.call(request)
end
Rails.application.config.middleware.use Rack::Attack

# Đoạn code Ruby on Rails này đang cấu hình Rate Limiting (giới hạn số lần gửi request) bằng thư viện Rack::Attack,
#  nhằm chống spam đăng nhập và giảm nguy cơ tấn công Brute Force.
#  Cụ thể: Mỗi địa chỉ IP chỉ được gửi tối đa 10 request đăng nhập trong 60 giây tới hai endpoint được chỉ định.

# Share a counter across IPs and both HTML/JSON login endpoints. Never store email in Redis keys.
Rack::Attack.throttle("login/account", limit: 20, period: 5.minutes) do |request|
  if login_request.call(request)
    begin
      params = ActionDispatch::Request.new(request.env).request_parameters
      email = params["email"]
      if email.is_a?(String) && email.bytesize <= 254
        normalized = email.strip.downcase
        OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, normalized) unless normalized.empty?
      end
    rescue ActionDispatch::Http::Parameters::ParseError, Rack::QueryParser::ParameterTypeError
      nil # Rails returns the normal 400 for malformed request bodies.
    end
  end
end
Rack::Attack.throttled_responder = lambda do |request|
  period = request.env.fetch("rack.attack.match_data").fetch(:period)
  [ 429, { "content-type" => "application/json", "cache-control" => "no-store",
    "retry-after" => period.to_s }, [ '{"error":"rate_limited"}' ] ]
end

# Signed webhook ingress is independent of browser sessions. Limit before JSON parsing.
Rack::Attack.throttle("integration/webhook/ip", limit: 120, period: 60) do |request|
  path = Rack::Utils.unescape_path(request.path).squeeze('/')
  request.ip if request.post? && path.start_with?('/webhooks/integration/')
end
