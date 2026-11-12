require "test_helper"
require "minitest/mock"
class IntegrationHubTest < ActionDispatch::IntegrationTest
  def commands = HrmIntegration::Application::Commands
  def verifier = HrmIntegration::Domain::Services::WebhookSignature
  def setup_connection
    @admin = make_user(:admin)
    result = commands::CreateConnection.new.call(actor: @admin, attributes: { code: "EXT", name: "External ERP" })
    @connection, @secret = result.values_at(:record, :secret)
    @connection = commands::ToggleConnection.new.call(actor: @admin, id: @connection.id, active: true, lock_version: 0)
    @body = { event_type: "external.notification", payload: { private_value: "SENSITIVE_PAYLOAD" } }.to_json
  end
  def signature(body = @body, id: "evt-1", timestamp: Time.current.to_i.to_s, secret: @secret)
    { public_id: @connection.public_id, timestamp: timestamp, event_id: id,
     signature: OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{id}.#{body}"), body: body }
  end
  def receive(**options) = commands::ReceiveWebhook.new.call(**signature(**options))
  def post_webhook(body = @body, **options)
    data = signature(body, **options)
    post "/webhooks/integration/#{@connection.public_id}", params: body,
      headers: { "CONTENT_TYPE" => "application/json", "X-Webhook-Timestamp" => data[:timestamp],
        "X-Webhook-Id" => data[:event_id], "X-Webhook-Signature" => data[:signature] }
  end
  def login(user = @admin)
    post "/session", params: { email: user.email, password: "StrongPassword123!" }
  end
  test "connection secret is encrypted and never serialized by normal reads" do
    setup_connection
    raw = IntegrationConnection.connection.select_value("SELECT signing_secret FROM integration_connections WHERE id=#{@connection.id.to_i}")
    assert_not_includes raw, @secret
    assert_not_includes @connection.to_json, @secret
    assert_equal 64, @secret.size
    login
    get "/integration/connections/#{@connection.id}"
    assert_response :success
    assert_not_includes response.body, @secret
    assert_includes response.headers["Cache-Control"], "no-store"
  end
  test "signed receipt is tenant derived encrypted atomic and idempotent" do
    setup_connection
    assert_difference [ "IntegrationWebhook.count", "AuditLog.count", "OutboxEvent.count" ], 1 do
      @received = receive
    end
    assert_no_difference [ "IntegrationWebhook.count", "AuditLog.count", "OutboxEvent.count" ] do
      assert_equal({ id: @received[:id], duplicate: true }, receive)
    end
    webhook = IntegrationWebhook.find(@received[:id])
    assert_equal @admin.company_id, webhook.company_id
    assert_equal @body, webhook.payload
    raw = IntegrationWebhook.connection.select_value("SELECT payload FROM integration_webhooks WHERE id=#{webhook.id.to_i}")
    assert_not_includes raw, "SENSITIVE_PAYLOAD"
    assert_not_includes webhook.to_json, "SENSITIVE_PAYLOAD"
  end
  test "HMAC covers event id timestamp and exact raw body" do
    setup_connection
    data = signature
    %i[event_id timestamp body].each do |key|
      tampered = data.merge(key => (key == :timestamp ? (Time.current.to_i + 10).to_s : data[key] + "x"))
      assert_raises(verifier::Unauthorized) { commands::ReceiveWebhook.new.call(**tampered) }
    end
    assert_raises(verifier::Unauthorized) { receive(timestamp: (Time.current.to_i - 301).to_s) }
    assert_raises(verifier::Unauthorized) { receive(timestamp: (Time.current.to_i + 301).to_s) }
    assert_equal 0, IntegrationWebhook.count
  end
  test "conflicting reuse fails while case-distinct event IDs remain distinct" do
    setup_connection
    receive(id: "Event-A")
    assert_raises(verifier::Conflict) do
      commands::ReceiveWebhook.new.call(**signature(@body.sub("SENSITIVE_PAYLOAD", "changed"), id: "Event-A"))
    end
    receive(id: "event-a")
    assert_equal 2, IntegrationWebhook.count
  end
  test "deactivation rotation and disabled company revoke ingress" do
    setup_connection
    old = signature
    result = commands::RotateConnectionSecret.new.call(actor: @admin, id: @connection.id, lock_version: @connection.lock_version)
    @secret = result[:secret]
    @connection = result[:record]
    assert_raises(verifier::Unauthorized) { commands::ReceiveWebhook.new.call(**old) }
    receive
    @connection = commands::ToggleConnection.new.call(actor: @admin, id: @connection.id, active: false, lock_version: @connection.lock_version)
    assert_raises(verifier::Unauthorized) { receive(id: "evt-2") }
    @connection = commands::ToggleConnection.new.call(actor: @admin, id: @connection.id, active: true, lock_version: @connection.lock_version)
    @admin.company.update!(active: false)
    assert_raises(verifier::Unauthorized) { receive(id: "evt-2") }
  end
  test "HTTP webhook does not authenticate by cookie and rejects type size and schema" do
    setup_connection
    post_webhook
    assert_response :accepted
    assert_equal false, response.parsed_body["duplicate"]
    post_webhook
    assert_response :accepted
    assert_equal true, response.parsed_body["duplicate"]
    post_webhook("x" * 65537, id: "too-large")
    assert_response :content_too_large
    post_webhook("{malformed SENSITIVE_PAYLOAD", id: "bad-json")
    assert_response :bad_request
    post_webhook({ event_type: "external.notification", payload: [] }.to_json, id: "bad-payload")
    assert_response :bad_request
    post "/webhooks/integration/#{@connection.public_id}", params: @body, headers: { "CONTENT_TYPE" => "text/plain" }
    assert_response :unsupported_media_type
    login
    post "/webhooks/integration/#{@connection.public_id}", params: @body, headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :unauthorized
  end
  test "unknown endpoint and malformed headers do not expose connection existence" do
    setup_connection
    path = "/webhooks/integration/#{SecureRandom.uuid}"
    post path, params: @body, headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :unauthorized
    post_webhook(timestamp: "bad")
    assert_response :unauthorized
    post_webhook(id: "bad id")
    assert_response :unauthorized
  end
  test "payload access uses separate revocable permission even for an existing API token" do
    setup_connection
    record = IntegrationWebhook.find(receive[:id])
    headers = { "Authorization" => "Bearer #{ApiToken.issue!(@admin)}" }
    get "/api/v1/integration/inbox/#{record.id}", headers: headers
    assert_response :success
    assert_not_includes response.body, "SENSITIVE_PAYLOAD"
    get "/api/v1/integration/inbox/#{record.id}/payload", headers: headers
    assert_response :success
    assert_includes response.body, "SENSITIVE_PAYLOAD"
    @admin.user_permissions.create!(permission: Permission.find_by!(key: "integration.payload.read"), granted: false)
    get "/api/v1/integration/inbox/#{record.id}/payload", headers: headers
    assert_response :forbidden
    get "/api/v1/integration", headers: headers
    assert_response :success
    assert_not_includes response.body, @secret
    assert_not_includes response.body, "SENSITIVE_PAYLOAD"
  end
  test "company scope and command authorization reject other companies and employee accounts" do
    setup_connection
    record = IntegrationWebhook.find(receive[:id])
    other = make_user(:admin, company: Company.create!(code: "HUB#{SecureRandom.hex(4).upcase}", name: "Other"))
    assert_raises ActiveRecord::RecordNotFound do
      commands::ToggleConnection.new.call(actor: other, id: @connection.id, active: false, lock_version: 1)
    end
    assert_raises ActiveRecord::RecordNotFound do
      commands::ReviewWebhook.new.call(actor: other, id: record.id, decision: "acknowledged", lock_version: 0)
    end
    employee = make_user(:employee)
    assert_raises Pundit::NotAuthorizedError do
      commands::CreateConnection.new.call(actor: employee, attributes: { code: "DENIED", name: "Denied" })
    end
    login(employee)
    get "/integration"
    assert_response :forbidden
  end
  test "review is locked terminal and never applies HR mutations" do
    setup_connection
    record = IntegrationWebhook.find(receive[:id])
    before = [ Employee.count, PayRun.count ]
    updated = commands::ReviewWebhook.new.call(actor: @admin, id: record.id, decision: "acknowledged", note: "PRIVATE_REVIEW", lock_version: 0)
    assert_equal "acknowledged", updated.status
    assert updated.reviewed_at.present?
    assert_equal before, [ Employee.count, PayRun.count ]
    assert_raises ActiveRecord::StaleObjectError do
      commands::ReviewWebhook.new.call(actor: @admin, id: record.id, decision: "rejected", lock_version: 0)
    end
    assert_raises ActiveRecord::RecordInvalid do
      commands::ReviewWebhook.new.call(actor: @admin, id: record.id, decision: "rejected", lock_version: updated.lock_version)
    end
    raw = IntegrationWebhook.connection.select_value("SELECT review_note FROM integration_webhooks WHERE id=#{record.id.to_i}")
    assert_not_includes raw, "PRIVATE_REVIEW"
  end
  test "API creation allowlist returns a fresh secret only once and validates inputs" do
    @admin = make_user(:admin)
    headers = { "Authorization" => "Bearer #{ApiToken.issue!(@admin)}" }
    post "/api/v1/integration/connections", params: { integration_connection: { code: "API", name: "API source", active: true, company_id: 999, signing_secret: "attacker" } }, headers: headers, as: :json
    assert_response :created
    data = response.parsed_body
    assert_equal false, data["active"]
    assert_equal 64, data["signing_secret"].length
    get "/api/v1/integration/connections/#{data['id']}", headers: headers
    assert_response :success
    assert_nil response.parsed_body["signing_secret"]
    post "/api/v1/integration/connections", params: { integration_connection: "bad" }, headers: headers, as: :json
    assert_response :bad_request
    get "/api/v1/integration", params: { page: { malformed: true } }, headers: headers
    assert_response :bad_request
  end
  test "inbox filters paginate source counts and malformed IDs fail closed" do
    setup_connection
    26.times { |i| receive(id: "evt-#{i}") }
    login
    get "/integration"
    assert_response :success
    assert_select "a[href^='/integration/inbox/']", count: 25
    assert_select "a", text: "Tiếp →"
    get "/integration", params: { page: 2 }
    assert_response :success
    assert_select "a[href^='/integration/inbox/']", count: 1
    get "/integration", params: { status: "invalid" }
    assert_response :bad_request
    get "/integration/connections/not-a-number"
    assert_response :not_found
  end
  test "MySQL composite foreign key enforces company connection ownership" do
    setup_connection
    other = Company.create!(code: "HUB#{SecureRandom.hex(4).upcase}", name: "Other")
    assert_raises ActiveRecord::InvalidForeignKey do
      IntegrationWebhook.insert_all!([ { company_id: other.id, integration_connection_id: @connection.id, # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
        event_id: "wrong-company", event_type: "test", body_digest: "a" * 64, payload: "{}", status: "received", created_at: Time.current, updated_at: Time.current } ])
    end
  end
  test "CSRF is still required for logged-in management mutations" do
    setup_connection
    login
    old = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    patch "/integration/connections/#{@connection.id}/status", params: { active: false, lock_version: 1 }
    assert_response :unprocessable_entity
    assert @connection.reload.active?
  ensure
    ActionController::Base.allow_forgery_protection = old
  end
  test "public webhook IP throttle is enforced with shared middleware enabled" do
    setup_connection
    old_enabled, old_store = Rack::Attack.enabled, Rack::Attack.cache.store
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    120.times { post_webhook }
    assert_response :accepted
    post_webhook
    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
    assert_equal 1, IntegrationWebhook.count
  ensure
    Rack::Attack.enabled = old_enabled
    Rack::Attack.cache.store = old_store
  end
  test "failed outbox append rolls back receipt and its audit together" do
    setup_connection
    original = Hrm::Container.method(:resolve)
    broken = Object.new
    def broken.append!(**) = raise(IOError, "outbox unavailable")
    resolver = ->(contract) { contract == HrmPlatform::Domain::Repositories::OutboxRepositoryInterface ? broken : original.call(contract) }
    assert_no_difference [ "IntegrationWebhook.count", "AuditLog.count", "OutboxEvent.count" ] do
      Hrm::Container.stub(:resolve, resolver) do
        assert_raises(IOError) { receive }
      end
    end
  end
  test "large valid payload fits encrypted MySQL storage without leaking into metadata" do
    setup_connection
    body = { event_type: "external.document", payload: { content: "Z" * 65_000 } }.to_json
    assert body.bytesize < verifier::MAX_BYTES
    post_webhook(body)
    assert_response :accepted
    record = IntegrationWebhook.last
    assert_equal body, record.payload
    assert_equal "mediumtext", IntegrationWebhook.columns_hash.fetch("payload").sql_type
  end
  test "normal metadata views escape names and payload output never runs HTML" do
    setup_connection
    @connection.update!(name: "<script>unsafe()</script>")
    login
    get "/integration"
    assert_response :success
    assert_not_includes response.body, "<script>unsafe()"
    body = '{"event_type":"external.notification","payload":{"content":"<script>payload()</script>"}}'
    result = commands::ReceiveWebhook.new.call(**signature(body))
    get "/integration/inbox/#{result[:id]}/payload"
    assert_response :success
    assert_includes response.body, "&lt;script&gt;payload()"
    assert_not_includes response.body, "<script>payload()"
  end

  test "invalid signature on malformed JSON is rejected before automatic JSON parsing" do
    setup_connection
    post_webhook("{malformed_PRIVATE_BODY", secret: "incorrect-key")
    assert_response :unauthorized
    assert_equal "unauthorized_webhook", response.parsed_body["error"]
    assert_equal 0, IntegrationWebhook.count
  end
  test "body middleware caps reads and hides JSON from parameter logging instrumentation" do
    bytes = StringIO.new("x" * 70_000)
    delegate_called = false
    guard = HrmIntegration::Infrastructure::Http::WebhookBodyLimit.new(->(_) { delegate_called = true; [ 202, {}, [] ] })
    result = guard.call({ "PATH_INFO" => "/webhooks/integration/test", "REQUEST_METHOD" => "POST", "CONTENT_TYPE" => "application/json", "rack.input" => bytes })
    assert_equal 413, result.first
    assert_equal 65_537, bytes.pos
    assert_not delegate_called
    small = "{}"
    guard = HrmIntegration::Infrastructure::Http::WebhookBodyLimit.new(lambda do |env|
      assert_equal "application/octet-stream", env["CONTENT_TYPE"]
      assert_equal true, env["hrm.integration.webhook_json"]
      assert_equal small, env["rack.input"].read
      [ 202, {}, [] ]
    end)
    assert_equal 202, guard.call({ "PATH_INFO" => "/webhooks/integration/test", "REQUEST_METHOD" => "POST", "CONTENT_TYPE" => "application/json", "rack.input" => StringIO.new(small) }).first
  end

  test "binary HTTP input preserves valid Vietnamese UTF-8 through encryption" do
    setup_connection
    body = '{"event_type":"external.notification","payload":{"message":"Xin chào nhân sự"}}'.b
    post_webhook(body)
    assert_response :accepted
    stored = IntegrationWebhook.last.payload
    assert stored.valid_encoding?
    assert_equal Encoding::UTF_8, stored.encoding
    assert_equal body.bytes, stored.bytes
    assert_equal "Xin chào nhân sự", JSON.parse(stored).fetch("payload").fetch("message")
  end
end
