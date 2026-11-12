require "test_helper"
require "rack/mock"
class LoginThrottleTest < ActiveSupport::TestCase
  def setup
    super
    @old_enabled = Rack::Attack.enabled
    @old_store = Rack::Attack.cache.store
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    @app = Rack::Attack.new(->(_env) { [ 200, {}, [ "ok" ] ] })
  end
  def teardown
    Rack::Attack.enabled = @old_enabled
    Rack::Attack.cache.store = @old_store
    super
  end
  def request(path, ip:, email:, json: false)
    body = json ? { email: email, password: "wrong" }.to_json : Rack::Utils.build_query(email: email, password: "wrong")
    @app.call(Rack::MockRequest.env_for(path, method: "POST", input: body,
      "CONTENT_TYPE" => json ? "application/json" : "application/x-www-form-urlencoded", "REMOTE_ADDR" => ip))
  end
  test "IP rate limit covers format suffixes and gives retry after without account details" do
    10.times { |i| assert_equal 200, request("/api/v1/session.json", ip: "192.0.2.1", email: "user#{i}@example.test")[0] }
    status, headers, body = request("/api/v1/session", ip: "192.0.2.1", email: "next@example.test")
    assert_equal 429, status
    assert headers["retry-after"].to_i.positive?
    assert_equal '{"error":"rate_limited"}', body.join
  end
  test "normalized account limit combines JSON and form attempts across IP addresses" do
    20.times do |i|
      path = i.even? ? "/session" : "/api/v1/session.json"
      assert_equal 200, request(path, ip: "192.0.2.#{i + 1}", email: i.even? ? " Person@Example.Test " : "person@example.test", json: i.odd?)[0]
    end
    assert_equal 429, request("/api/v1/session", ip: "192.0.2.100", email: "person@example.test", json: true)[0]
    assert_equal 200, request("/session", ip: "192.0.2.101", email: "other@example.test")[0]
  end
  test "malformed JSON does not crash rate limit middleware" do
    env = Rack::MockRequest.env_for("/api/v1/session", method: "POST", input: "{bad", "CONTENT_TYPE" => "application/json", "REMOTE_ADDR" => "192.0.2.1")
    assert_equal 200, @app.call(env)[0] # Terminal test app only; Rails handles the 400 afterwards.
  end
  test "escaped letters and repeated slashes cannot bypass shared IP counter" do
    paths = [ "/session.json", "/%73ession", "/api//v1/session.html/" ]
    10.times do |i|
      assert_equal 200, request(paths[i % paths.length], ip: "192.0.2.8", email: "user#{i}@example.test")[0]
    end
    assert_equal 429, request("/api/v1/session", ip: "192.0.2.8", email: "other@example.test")[0]
  end
end
