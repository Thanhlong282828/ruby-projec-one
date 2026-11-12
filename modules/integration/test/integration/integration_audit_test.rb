require "test_helper"
require "minitest/mock"
class IntegrationAuditTest < ActionDispatch::IntegrationTest
  def setup
    super
    @admin = make_user(:admin)
    @connection = HrmIntegration::Application::Commands::CreateConnection.new.call(actor: @admin,
      attributes: { code: "AUDIT", name: "Private partner" })[:record]
  end
  def workspace(actor: @admin, **filters)
    HrmIntegration::Application::Queries::AuditWorkspace.new.call(actor: actor, **filters)
  end
  def headers(user = @admin) = { "Authorization" => "Bearer #{ApiToken.issue!(user)}" }
  def log_for(type: "IntegrationConnection", id: @connection.id, company: @admin.company, operation: "updated", metadata: {}, at: Time.current)
    AuditLog.create!(company: company, action: operation, record_type: type, record_id: id, metadata: metadata, created_at: at)
  end
  def grant(user, *keys)
    keys.each { |key| user.user_permissions.create!(permission: Permission.find_by!(key: key), granted: true) }
  end
  test "portal uses dedicated permission with integration read and never global audit access" do
    auditor = make_user(:employee)
    assert_not auditor.allowed?("audit.read")
    grant(auditor, "integration.read")
    assert_raises(Pundit::NotAuthorizedError) { workspace(actor: auditor) }
    grant(auditor, "integration.audit.read")
    assert workspace(actor: auditor)[:records].any?
    assert_not auditor.allowed?("integration.payload.read")
    assert_not auditor.allowed?("audit.read")
    grant(make_user(:employee), "audit.read")
    outsider = make_user(:employee)
    grant(outsider, "audit.read", "integration.audit.read")
    assert_raises(Pundit::NotAuthorizedError) { workspace(actor: outsider) }
  end
  test "company and module scopes apply to results counts forged parameters and direct repository" do
    other = make_user(:admin, company: Company.create!(code: "AUD#{SecureRandom.hex(4).upcase}", name: "Other"))
    foreign = log_for(company: other.company, metadata: { secret: "FOREIGN_PRIVATE" })
    unrelated = log_for(type: "User", id: @admin.id, metadata: { secret: "USER_PRIVATE" })
    own = log_for(metadata: { changed_fields: [ "name" ] })
    result = workspace
    assert_includes result[:records].pluck(:id), own.id
    assert_not_includes result[:records].pluck(:id), foreign.id
    assert_not_includes result[:records].pluck(:id), unrelated.id
    assert_equal 1, result[:counts]["updated"]
    get "/api/v1/integration/audit", params: { company_id: other.company_id, record_type: "User" }, headers: headers
    assert_response :success
    assert_not_includes response.body, "FOREIGN_PRIVATE"
    assert_not_includes response.parsed_body["records"].pluck("id"), foreign.id
    denied = make_user(:employee)
    repository = Hrm::Container.resolve(HrmIntegration::Domain::Repositories::AuditReadRepositoryInterface)
    assert_raises(Pundit::NotAuthorizedError) do
      repository.workspace(actor: denied, filters: HrmIntegration::Domain::Services::AuditFilters.new)
    end
  end
  test "metadata projection discards arbitrary values payload credentials malformed fields and raw actor details" do
    log_for(metadata: { changed_fields: [ "name", "signing_secret", "PRIVATE_FRAGMENT", { secret: "SECRET_VALUE" }, "name" ],
      payload: "SENSITIVE_BODY", signing_secret: @connection.signing_secret, email: @admin.email })
    get "/api/v1/integration/audit", headers: headers
    assert_response :success
    [ "PRIVATE_FRAGMENT", "SECRET_VALUE", "SENSITIVE_BODY", @connection.signing_secret, @admin.email ].each do |secret|
      assert_not_includes response.body, secret
    end
    row = response.parsed_body["records"].find { |entry| entry["action"] == "updated" }
    assert_equal %w[name signing_secret], row["changed_fields"]
    assert_equal %w[action actor_id attempt changed_fields id occurred_at record_id record_type source_url], row.keys.sort
    assert_includes response.headers["Cache-Control"], "no-store"
    log_for(metadata: { changed_fields: "NOT_AN_ARRAY" })
    assert_equal [], workspace[:records].first[:changed_fields]
  end
  test "revoked grants affect existing API credential and source navigation immediately" do
    token_headers = headers
    get "/api/v1/integration/audit", headers: token_headers
    assert_response :success
    @admin.user_permissions.create!(permission: Permission.find_by!(key: "integration.audit.read"), granted: false)
    get "/api/v1/integration/audit", headers: token_headers
    assert_response :forbidden
    assert_raises(Pundit::NotAuthorizedError) { workspace }
    post "/session", params: { email: @admin.email, password: "StrongPassword123!" }
    get "/integration"
    assert_response :success
    assert_select "a[href='/integration/audit']", count: 0
    get "/integration/audit"
    assert_response :forbidden
  end
  test "portal requires authentication on web and token on API with no cookie fallback" do
    get "/integration/audit"
    assert_response :redirect
    get "/api/v1/integration/audit"
    assert_response :unauthorized
    post "/session", params: { email: @admin.email, password: "StrongPassword123!" }
    get "/api/v1/integration/audit"
    assert_response :unauthorized
    get "/integration/audit"
    assert_response :success
    assert_select "h1", text: "Nhật ký tích hợp"
  end
  test "strict filters reject shapes arbitrary classes invalid dates SQL injection and oversized ids" do
    invalid = [ { resource: "User" }, { operation: "created OR 1=1" }, { resource: {} }, { operation: [] },
      { from: "2026-02-31" }, { to: (Date.current + 1).to_s }, { from: (Date.current - 93).to_s },
      { from: Date.current.to_s, to: (Date.current - 1).to_s }, { before: "0" }, { before: "1 OR 1=1" },
      { record_id: 1 }, { resource: "connection", record_id: "9223372036854775808" }, { before: {} }, { from: [] } ]
    invalid.each do |filters|
      assert_raises(HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload, filters.inspect) { workspace(**filters) }
    end
    token_headers = headers
    invalid.each do |filters|
      get "/api/v1/integration/audit", params: filters, headers: token_headers
      # Empty collection values may be removed by Rack encoding, so exercise nonempty HTTP shapes separately.
      assert_response :bad_request unless filters.values.any? { |value| value == {} || value == [] }
    end
    get "/api/v1/integration/audit", params: { operation: { malformed: "created" } }, headers: token_headers
    assert_response :bad_request
  end
  test "date range uses application day boundaries includes final day and excludes following day" do
    travel_to(Time.zone.local(2026, 11, 12, 10)) do
      yesterday = Date.current - 1
      include_log = log_for(at: yesterday.end_of_day)
      exclude_log = log_for(at: Date.current.beginning_of_day)
      result = workspace(from: yesterday.to_s, to: yesterday.to_s)
      assert_includes result[:records].pluck(:id), include_log.id
      assert_not_includes result[:records].pluck(:id), exclude_log.id
      assert_equal Time.zone.name, result[:timezone]
      assert workspace(from: (Date.current - 92).to_s, to: Date.current.to_s)
    end
  end
  test "resource record and action filter counts remain source linked through HTTP operation param" do
    updated = log_for(metadata: { changed_fields: [ "name" ] })
    log_for(type: "IntegrationWebhook", id: 999999)
    result = workspace(resource: "connection", record_id: @connection.id.to_s, operation: "updated")
    assert_equal([ updated.id ], result[:records].pluck(:id))
    assert_equal 1, result[:counts]["created"]
    assert_equal 1, result[:counts]["updated"]
    get "/api/v1/integration/audit", params: { resource: "connection", record_id: @connection.id, operation: "updated" }, headers: headers
    assert_response :success
    assert_equal([ updated.id ], response.parsed_body["records"].pluck("id"))
    post "/session", params: { email: @admin.email, password: "StrongPassword123!" }
    get "/integration/audit", params: { resource: "connection", record_id: @connection.id, operation: "updated" }
    assert_response :success
    assert_select "a.metric-card[href*='operation=created'][href*='resource=connection'][href*='record_id=']"
    assert_select "a[href='/integration/connections/#{@connection.id}']"
    get "/integration/connections/#{@connection.id}"
    assert_response :success
    assert_select "a[href='/integration/audit?resource=connection&record_id=#{@connection.id}']"
  end
  test "keyset pages do not repeat entries when a newer audit is inserted" do
    26.times { log_for }
    first = workspace(operation: "updated")
    assert_equal 25, first[:records].size
    assert first[:next_before]
    log_for
    second = workspace(operation: "updated", before: first[:next_before])
    assert_equal 1, second[:records].size
    assert_empty first[:records].pluck(:id) & second[:records].pluck(:id)
    assert_nil second[:next_before]
  end
  test "attempt audit includes safe HTTP outcome and links to the scoped parent delivery" do
    connection = @connection.reload
    connection.update!(active: true)
    delivery = IntegrationDelivery.create!(company: @admin.company, integration_connection: connection, requested_by: @admin,
      target_key: "partner", event_id: SecureRandom.uuid, idempotency_key: "audit-attempt", payload: "PRIVATE_PAYLOAD",
      body_digest: "a" * 64, available_at: Time.current)
    attempt = delivery.integration_delivery_attempts.create!(company: @admin.company, sequence: 1,
      outcome: "http_error", http_status: 503, started_at: Time.current, completed_at: Time.current)
    result = workspace(resource: "attempt", record_id: attempt.id)
    row = result[:records].first
    assert_equal({ sequence: 1, http_status: 503, outcome: "http_error" }, row[:attempt])
    assert_equal "/integration/outbound/#{delivery.id}", row[:source_url]
    assert_not_includes result.to_json, "PRIVATE_PAYLOAD"
  end
  test "deleted source preserves audit but does not advertise a broken source link" do
    entry = log_for(id: 999999999, operation: "deleted")
    row = workspace(operation: "deleted")[:records].find { |item| item[:id] == entry.id }
    assert_nil row[:source_url]
    assert_equal "deleted", row[:action]
  end
  test "read does not create audit outbox mail jobs or decrypt connection credentials" do
    assert_no_difference [ "AuditLog.count", "OutboxEvent.count", "IntegrationConnection.count" ] do
      assert_no_enqueued_jobs do
        workspace
      end
    end
    # Source lookups only pluck IDs; instrument SQL to detect full source loading.
    queries = []
    callback = ->(_name, _start, _finish, _id, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { workspace }
    assert_not(queries.any? { |sql| sql.include?('SELECT `integration_connections`.*') })
  end
  test "query authorizes before invoking an injected repository" do
    repository = Object.new
    def repository.workspace(**) = raise("Repository should not run for unauthorized actor")
    assert_raises(Pundit::NotAuthorizedError) do
      HrmIntegration::Application::Queries::AuditWorkspace.new(repository: repository).call(actor: make_user(:employee))
    end
  end
end
