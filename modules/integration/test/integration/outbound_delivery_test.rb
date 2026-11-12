require "test_helper"
require "minitest/mock"
class OutboundDeliveryTest < ActionDispatch::IntegrationTest
  def setup
    super
    @previous_targets = ENV["INTEGRATION_TARGETS_JSON"]
    @admin = make_user(:admin)
    ENV["INTEGRATION_TARGETS_JSON"] = { partner: { url: "https://partner.example.test/hook", company_ids: [ @admin.company_id ] } }.to_json
    result = HrmIntegration::Application::Commands::CreateConnection.new.call(actor: @admin, attributes: { code: "SEND", name: "Partner" })
    @connection = result[:record]
    HrmIntegration::Application::Commands::ToggleConnection.new.call(actor: @admin, id: @connection.id, active: true, lock_version: 0)
    @body = { event_type: "external.notification", payload: { private_text: "PRIVATE_OUTBOUND" } }.to_json
  end
  def teardown
    ENV["INTEGRATION_TARGETS_JSON"] = @previous_targets
    super
  end
  def enqueue(**overrides)
    HrmIntegration::Application::Commands::QueueDelivery.new.call(**{ actor: @admin, connection_id: @connection.id, target_key: "partner", body: @body, idempotency_key: "invoice-1" }.merge(overrides))
  end
  def deliver(record, code: 200, outcome: nil)
    result = { code: code, outcome: outcome || (code.between?(200, 299) ? "delivered" : "http_error") }
    transport = ->(**attributes) { @sent_attributes = attributes; result }
    HrmIntegration::Infrastructure::Persistence::ActiveRecordDeliveryRepository.new(transport: transport).deliver!(id: record.id)
    record.reload
  end
  def retry_delivery(record, **overrides)
    HrmIntegration::Application::Commands::RetryDelivery.new.call(**{ actor: @admin, id: record.id, lock_version: record.reload.lock_version }.merge(overrides))
  end
  test "durable queue encrypted atomic and same key same bytes returns existing row" do
    assert_difference [ "IntegrationDelivery.count", "AuditLog.count", "OutboxEvent.count" ], 1 do
      @record = enqueue
    end
    assert_equal "queued", @record.status
    assert_no_difference [ "IntegrationDelivery.count", "AuditLog.count", "OutboxEvent.count" ] do
      assert_equal @record.id, enqueue.id
    end
    assert_raises HrmIntegration::Domain::Services::WebhookSignature::Conflict do
      enqueue(body: @body.sub("PRIVATE_OUTBOUND", "different"))
    end
    raw = IntegrationDelivery.connection.select_value("SELECT payload FROM integration_deliveries WHERE id=#{@record.id.to_i}")
    assert_not_includes raw, "PRIVATE_OUTBOUND"
    assert_not_includes @record.to_json, "PRIVATE_OUTBOUND"
    assert_equal @admin.company_id, @record.company_id
  end
  test "input allowlist rejects unknown destination malformed bodies and oversize" do
    [ nil, {}, "https://127.0.0.1", "unknown" ].each do |key|
      assert_raises HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload do
        enqueue(target_key: key)
      end
    end
    [ "not json", "[]", @body + "x", "x" * 65_537 ].each do |body|
      assert_raises HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload do
        enqueue(body: body)
      end
    end
    assert_equal 0, IntegrationDelivery.count
  end
  test "successful worker appends attempt once and duplicate worker never sends delivered event" do
    record = enqueue
    assert_difference [ "IntegrationDeliveryAttempt.count" ], 1 do
      deliver(record)
    end
    assert_equal "delivered", record.status
    assert record.delivered_at
    assert_equal 1, record.attempt_count
    assert_equal record.event_id, @sent_attributes[:event_id]
    assert_equal @body, @sent_attributes[:body]
    assert_no_difference "IntegrationDeliveryAttempt.count" do
      deliver(record)
    end
    assert_raises HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload do
      retry_delivery(record)
    end
  end
  test "retry respects due time goes dead letter after five failures and replay preserves identity" do
    record = enqueue
    deliver(record, code: 503)
    assert_equal "retry_wait", record.status
    assert record.available_at > Time.current
    assert_no_difference "IntegrationDeliveryAttempt.count" do
      deliver(record, code: 503)
    end
    4.times do
      travel_to(record.available_at + 1.second) { deliver(record, code: 503) }
    end
    assert_equal "dead_letter", record.status
    assert_equal 5, record.attempt_count
    event_id = record.event_id
    retry_delivery(record)
    deliver(record)
    assert_equal "delivered", record.status
    assert_equal event_id, record.event_id
    assert_equal 1, record.replay_count
    assert_equal (1..6).to_a, record.integration_delivery_attempts.order(:sequence).pluck(:sequence)
  end
  test "permanent failure dead letters immediately while 429 waits and replay is version guarded" do
    record = enqueue
    deliver(record, code: 400)
    assert_equal "dead_letter", record.status
    assert_raises ActiveRecord::StaleObjectError do
      retry_delivery(record, lock_version: 0)
    end
    retry_delivery(record)
    deliver(record, code: 429)
    assert_equal "retry_wait", record.status
  end
  test "revoked sender privilege blocks existing queued work without making a network attempt" do
    record = enqueue
    @admin.user_permissions.create!(permission: Permission.find_by!(key: "integration.send"), granted: false)
    assert_no_difference "IntegrationDeliveryAttempt.count" do
      deliver(record)
    end
    assert_equal "blocked", record.status
    assert_nil @sent_attributes
    assert_raises Pundit::NotAuthorizedError do
      enqueue(idempotency_key: "new-key")
    end
  end
  test "disabled connection company and account block network independently" do
    record = enqueue
    @connection.reload.update!(active: false)
    deliver(record)
    assert_equal "blocked", record.status
    assert_nil @sent_attributes
    @connection.update!(active: true)
    retry_delivery(record)
    @admin.company.update!(active: false)
    deliver(record)
    assert_equal "blocked", record.status
    assert_nil @sent_attributes
  end
  test "cross company read retry enqueue and database links are rejected" do
    record = enqueue
    other = make_user(:admin, company: Company.create!(code: "OUT#{SecureRandom.hex(4).upcase}", name: "Other"))
    assert_raises ActiveRecord::RecordNotFound do
      HrmIntegration::Application::Queries::FindDelivery.new.call(actor: other, id: record.id)
    end
    assert_raises ActiveRecord::RecordNotFound do
      retry_delivery(record, actor: other)
    end
    assert_raises HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload do
      enqueue(actor: other)
    end
    assert_raises ActiveRecord::InvalidForeignKey do
      IntegrationDeliveryAttempt.insert_all!([ { company_id: other.company_id, integration_delivery_id: record.id, sequence: 1, # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
        outcome: "delivered", started_at: Time.current, completed_at: Time.current, created_at: Time.current, updated_at: Time.current } ])
    end
  end
  test "metadata API payload permission revocation UI source links and malformed filters" do
    record = enqueue
    token = ApiToken.issue!(@admin)
    headers = { "Authorization" => "Bearer #{token}" }
    get "/api/v1/integration/outbound/#{record.id}", headers: headers
    assert_response :success
    assert_not_includes response.body, "PRIVATE_OUTBOUND"
    get "/api/v1/integration/outbound/#{record.id}/payload", headers: headers
    assert_response :success
    assert_includes response.body, "PRIVATE_OUTBOUND"
    @admin.user_permissions.create!(permission: Permission.find_by!(key: "integration.payload.read"), granted: false)
    get "/api/v1/integration/outbound/#{record.id}/payload", headers: headers
    assert_response :forbidden
    get "/api/v1/integration/outbound", params: { page: {}, status: "<script>" }, headers: headers
    assert_response :bad_request
    post "/session", params: { email: @admin.email, password: "StrongPassword123!" }
    get "/integration/outbound"
    assert_response :success
    assert_select "a[href='/integration/outbound?status=queued']"
    assert_select "a[href='/integration/outbound/#{record.id}']"
    assert_includes response.headers["Cache-Control"], "no-store"
  end
  test "API enqueue ignores malicious company status actor and URL fields and web retains CSRF" do
    headers = { "Authorization" => "Bearer #{ApiToken.issue!(@admin)}" }
    data = { connection_id: @connection.id, target_key: "partner", body: @body, idempotency_key: "api-1",
      company_id: 999999, requested_by_id: 999999, status: "delivered", url: "http://127.0.0.1/" }
    post "/api/v1/integration/outbound", params: { delivery: data }, headers: headers, as: :json
    assert_response :accepted
    assert_equal "queued", response.parsed_body["status"]
    assert_equal @admin.company_id, response.parsed_body["company_id"]
    assert_equal @admin.id, response.parsed_body["requested_by_id"]
    assert_not_includes response.body, "PRIVATE_OUTBOUND"
    post "/session", params: { email: @admin.email, password: "StrongPassword123!" }
    old = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    post "/integration/outbound", params: { delivery: data }
    assert_response :unprocessable_entity
  ensure
    ActionController::Base.allow_forgery_protection = old
  end
  test "attempt history and payload cannot be rewritten by ordinary model updates" do
    record = enqueue
    deliver(record)
    assert_raises ActiveRecord::RecordInvalid do
      record.update!(payload: "changed")
    end
    attempt = record.integration_delivery_attempts.first
    assert_raises ActiveRecord::RecordInvalid do
      attempt.update!(outcome: "transport_error")
    end
    assert_not attempt.destroy
  end
  test "scheduler requeues durable rows after Redis handoff failure without losing database state" do
    record = enqueue
    IntegrationDeliveryJob.stub(:perform_later, ->(*) { raise IOError, "redis unavailable" }) do
      assert_raises(IOError) { IntegrationDispatchJob.perform_now }
    end
    assert_equal "queued", record.reload.status
    assert_enqueued_with(job: IntegrationDeliveryJob, args: [ record.id ]) do
      IntegrationDispatchJob.perform_now
    end
  end
  test "early manual retry still permits only five attempts in the next cycle" do
    record = enqueue
    deliver(record, code: 503)
    retry_delivery(record)
    5.times do
      travel_to(record.available_at + 1.second) { deliver(record, code: 503) }
    end
    assert_equal "dead_letter", record.status
    assert_equal 6, record.attempt_count
    assert_equal 5, record.cycle_attempt_count
  end
  test "payload HTML escaped and malformed filter shape rejected" do
    record = enqueue(body: @body.sub("PRIVATE_OUTBOUND", "<script>unsafe()</script>"))
    post "/session", params: { email: @admin.email, password: "StrongPassword123!" }
    get "/integration/outbound/#{record.id}/payload"
    assert_response :success
    assert_includes response.body, "&lt;script&gt;unsafe()"
    assert_not_includes response.body, "<script>unsafe()"
    get "/integration/outbound", params: { status: { invalid: "value" } }
    assert_response :bad_request
  end
  test "removing destination company grant blocks actual transport before any network" do
    record = enqueue
    ENV["INTEGRATION_TARGETS_JSON"] = { partner: { url: "https://partner.example.test/hook", company_ids: [ @admin.company_id + 100000 ] } }.to_json
    Net::HTTP.stub(:new, ->(*) { flunk "Must not connect to a revoked target" }) do
      HrmIntegration::Infrastructure::Persistence::ActiveRecordDeliveryRepository.new.deliver!(id: record.id)
    end
    assert_equal "retry_wait", record.reload.status
    assert_equal "target_unavailable", record.integration_delivery_attempts.last.outcome
  end
  test "binary Vietnamese body preserves exact bytes through outbound encryption" do
    body = '{"event_type":"external.notification","payload":{"message":"Xin chào nhân sự"}}'.b
    record = enqueue(body: body)
    assert_equal Encoding::UTF_8, record.reload.payload.encoding
    assert_equal body.bytes, record.payload.bytes
    deliver(record)
    assert_equal body.bytes, @sent_attributes[:body].bytes
  end
  test "replay budget cannot exceed ten even with valid fresh versions" do
    record = enqueue
    10.times do
      deliver(record, code: 400)
      retry_delivery(record)
    end
    deliver(record, code: 400)
    assert_equal "dead_letter", record.status
    assert_equal 10, record.replay_count
    assert_raises HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload do
      retry_delivery(record)
    end
  end
  test "outbox failure rolls back enqueue and audit atomically" do
    original = Hrm::Container.method(:resolve)
    broken = Object.new
    def broken.append!(**) = raise(IOError, "outbox unavailable")
    resolver = ->(contract) { contract == HrmPlatform::Domain::Repositories::OutboxRepositoryInterface ? broken : original.call(contract) }
    assert_no_difference [ "IntegrationDelivery.count", "AuditLog.count", "OutboxEvent.count" ] do
      Hrm::Container.stub(:resolve, resolver) { assert_raises(IOError) { enqueue } }
    end
  end
  test "generic sender cannot impersonate reserved business event namespaces" do
    %w[payroll payroll.export.ready erp.export.ready government.filing.ready].each do |event_type|
      body = { event_type: event_type, payload: { source_id: 1 } }.to_json
      assert_no_difference [ "IntegrationDelivery.count", "AuditLog.count", "OutboxEvent.count" ] do
        assert_raises HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload do
          enqueue(body: body)
        end
      end
    end
    headers = { "Authorization" => "Bearer #{ApiToken.issue!(@admin)}" }
    post "/api/v1/integration/outbound", params: { delivery: { connection_id: @connection.id,
      target_key: "partner", idempotency_key: "forged-payroll", body: { event_type: "payroll.export.ready", payload: {} }.to_json } }, headers: headers, as: :json
    assert_response :bad_request
    assert_equal "invalid_delivery", response.parsed_body["error"]
    assert_equal 0, IntegrationDelivery.count
  end

  test "changed valid JSON cannot be signed by worker and cannot be manually replayed" do
    record = enqueue
    # Simulate a privileged DB write bypassing application immutability.
    record.update_columns(payload: @body.sub("PRIVATE_OUTBOUND", "TAMPERED")) # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    assert_difference [ "AuditLog.count", "OutboxEvent.count" ], 1 do
      assert_no_difference "IntegrationDeliveryAttempt.count" do
        deliver(record)
      end
    end
    assert_equal "blocked", record.status
    assert_equal 0, record.attempt_count
    assert_nil @sent_attributes
    assert_raises HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload do
      retry_delivery(record)
    end
    assert_equal "blocked", record.reload.status
  end

  test "worker quarantines reserved schema invalid oversized and malformed UTF8 legacy payloads" do
    bodies = [
      { event_type: "payroll.export.ready", payload: { source_id: 1 } }.to_json,
      { event_type: "external.notification", payload: [] }.to_json,
      { event_type: "external.notification", payload: { text: "x" * 65_536 } }.to_json,
      "{invalid", "\xFF".b
    ]
    bodies.each_with_index do |body, index|
      record = enqueue(idempotency_key: "quarantine-#{index}")
      record.update_columns(payload: body, body_digest: Digest::SHA256.hexdigest(body)) # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
      deliver(record)
      assert_equal "blocked", record.status
      assert_equal 0, record.attempt_count
      assert_nil @sent_attributes
    end
    assert_equal 0, IntegrationDeliveryAttempt.count
  end

  test "broken ciphertext remains visible as metadata and is quarantined without decryption leaks" do
    record = enqueue
    sql = IntegrationDelivery.connection
    sql.execute("UPDATE integration_deliveries SET payload=#{sql.quote('broken-ciphertext')} WHERE id=#{record.id.to_i}")
    assert_not_includes record.reload.to_json, "broken-ciphertext"
    assert_not_includes record.public_attributes.keys, "payload"
    assert_difference [ "AuditLog.count", "OutboxEvent.count" ], 1 do
      deliver(record)
    end
    assert_equal "blocked", record.status
    assert_nil @sent_attributes
    assert_equal 0, record.attempt_count
    assert_raises HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload do
      retry_delivery(record)
    end
    headers = { "Authorization" => "Bearer #{ApiToken.issue!(@admin)}" }
    get "/api/v1/integration/outbound/#{record.id}", headers: headers
    assert_response :success
    assert_equal "blocked", response.parsed_body.dig("record", "status")
    assert_not_includes response.body, "broken-ciphertext"
  end

  test "quarantine rolls back if safe outbox evidence cannot be written" do
    record = enqueue
    record.update_columns(body_digest: "0" * 64) # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    original = Hrm::Container.method(:resolve)
    broken = Object.new
    def broken.append!(**) = raise(IOError, "outbox unavailable")
    resolver = ->(contract) { contract == HrmPlatform::Domain::Repositories::OutboxRepositoryInterface ? broken : original.call(contract) }
    assert_no_difference [ "AuditLog.count", "OutboxEvent.count", "IntegrationDeliveryAttempt.count" ] do
      Hrm::Container.stub(:resolve, resolver) { assert_raises(IOError) { deliver(record) } }
    end
    assert_equal "queued", record.reload.status
    assert_nil @sent_attributes
    deliver(record)
    assert_equal "blocked", record.status
  end
end
