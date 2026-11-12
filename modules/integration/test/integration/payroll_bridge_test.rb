require "test_helper"
require "minitest/mock"
class PayrollBridgeTest < ActionDispatch::IntegrationTest
  def setup
    super
    @admin = make_user(:admin)
    make_employee(employee_code: "PRIVATE_PAYROLL_EMPLOYEE")
    run = Payroll::BuildRun.call(period: Date.current, actor: @admin)
    Payroll::FinalizeRun.call(run: run, actor: @admin)
    @source = HrmPayroll::Application::Commands::CreateExport.new.call(actor: @admin, pay_run_id: run.id)
    @previous_targets = ENV["INTEGRATION_TARGETS_JSON"]
    ENV["INTEGRATION_TARGETS_JSON"] = { partner: { url: "https://partner.example.test/hook", company_ids: [ @admin.company_id ] }, second: { url: "https://second.example.test/hook", company_ids: [ @admin.company_id ] } }.to_json
    @connection = HrmIntegration::Application::Commands::CreateConnection.new.call(actor: @admin, attributes: { code: "PAYROLL", name: "Payroll partner" })[:record]
    HrmIntegration::Application::Commands::ToggleConnection.new.call(actor: @admin, id: @connection.id, active: true, lock_version: 0)
  end
  def teardown
    ENV["INTEGRATION_TARGETS_JSON"] = @previous_targets
    super
  end
  def enqueue(**overrides)
    HrmIntegration::Application::Commands::QueuePayrollNotification.new.call(**{ actor: @admin, export_id: @source.id, connection_id: @connection.id, target_key: "partner" }.merge(overrides))
  end
  def deliver(record)
    transport = ->(**attrs) { @sent = attrs; { code: 200, outcome: "delivered" } }
    HrmIntegration::Infrastructure::Persistence::ActiveRecordDeliveryRepository.new(transport: transport).deliver!(id: record.id)
    record.reload
  end
  def deny(user, key)
    row = user.user_permissions.find_or_initialize_by(permission: Permission.find_by!(key: key))
    row.update!(granted: false)
  end
  def headers = { "Authorization" => "Bearer #{ApiToken.issue!(@admin)}" }
  test "bridge queues verified source descriptor atomically and is idempotent per destination" do
    assert_difference [ "IntegrationDelivery.count", "AuditLog.count", "OutboxEvent.count" ], 1 do
      @record = enqueue
    end
    assert_equal @source.id, @record.payroll_export_id
    assert_no_difference [ "IntegrationDelivery.count", "AuditLog.count", "OutboxEvent.count" ] do
      assert_equal @record.id, enqueue.id
    end
    assert_not_equal @record.id, enqueue(target_key: "second").id
    payload = JSON.parse(@record.payload)
    assert_equal "payroll.export.ready", payload["event_type"]
    assert_equal @source.public_id, payload.dig("payload", "source_uuid")
    assert_equal @source.checksum, payload.dig("payload", "checksum")
    assert_equal %w[byte_size checksum format mime period source source_uuid version], payload["payload"].keys.sort
    assert_not_includes @record.payload, "PRIVATE_PAYROLL_EMPLOYEE"
    assert_not_includes @record.payload, "20000000"
    assert_equal 0, PayrollExportAccess.count
    deliver(@record)
    assert_equal "delivered", @record.status
    assert_equal @record.payload, @sent[:body]
    assert_equal @record.event_id, @sent[:event_id]
  end
  test "generic integration privileges cannot queue payroll notifications" do
    operator = make_user(:employee)
    %w[integration.read integration.send].each { |key| operator.user_permissions.create!(permission: Permission.find_by!(key: key), granted: true) }
    assert_raises(Pundit::NotAuthorizedError) { enqueue(actor: operator) }
    assert_raises(Pundit::NotAuthorizedError) { HrmIntegration::Infrastructure::Persistence::ActiveRecordPayrollBridgeRepository.new.enqueue!(actor: operator, export_id: @source.id, connection_id: @connection.id, target_key: "partner") }
    assert_equal 0, IntegrationDelivery.count
  end
  test "worker rechecks source notify grant and replay cannot bypass it" do
    record = enqueue
    deny(@admin, "payroll.exports.notify")
    deliver(record)
    assert_equal "blocked", record.status
    assert_nil @sent
    assert_equal 0, record.attempt_count
    assert_raises(Pundit::NotAuthorizedError) { HrmIntegration::Application::Commands::RetryDelivery.new.call(actor: @admin, id: record.id, lock_version: record.lock_version) }
  end
  test "corrupt source blocks queue worker and replay even when delivery digest still matches" do
    record = enqueue
    PayrollExport.where(id: @source.id).update_all(checksum: "0" * 64) # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    assert_raises(HrmPayroll::Domain::Services::PayrollCsv::IntegrityError) { enqueue }
    deliver(record)
    assert_equal "blocked", record.status
    assert_nil @sent
    assert_equal 0, record.attempt_count
    assert_raises(HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload) { HrmIntegration::Application::Commands::RetryDelivery.new.call(actor: @admin, id: record.id, lock_version: record.lock_version) }
  end
  test "delivery tampered with matching hash cannot change the source descriptor" do
    record = enqueue
    body = record.payload.sub(@source.public_id, SecureRandom.uuid)
    record.update_columns(payload: body, body_digest: Digest::SHA256.hexdigest(body)) # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    deliver(record)
    assert_equal "blocked", record.status
    assert_nil @sent
    assert_equal 0, IntegrationDeliveryAttempt.count
  end
  test "source ID is immutable and MySQL rejects foreign company source" do
    record = enqueue
    assert_raises(ActiveRecord::RecordInvalid) { record.update!(payroll_export_id: nil) }
    other = make_user(:admin, company: Company.create!(code: "BRIDGE#{SecureRandom.hex(4).upcase}", name: "Other"))
    assert_raises(HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload) { enqueue(actor: other) }
    assert_raises(ActiveRecord::RecordNotFound) do
      Hrm::Container.resolve(HrmPayroll::Domain::Repositories::ExportSourceRepositoryInterface).with_verified_descriptor(actor: other, id: @source.id) { flunk "foreign source" }
    end
    make_employee(other)
    other_run = Payroll::BuildRun.call(period: Date.current, actor: other)
    Payroll::FinalizeRun.call(run: other_run, actor: other)
    other_source = HrmPayroll::Application::Commands::CreateExport.new.call(actor: other, pay_run_id: other_run.id)
    assert_raises(ActiveRecord::InvalidForeignKey) { IntegrationDelivery.where(id: record.id).update_all(payroll_export_id: other_source.id) } # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    sql = IntegrationDelivery.connection
    assert_raises(ActiveRecord::InvalidForeignKey) do
      sql.execute("UPDATE integration_deliveries SET company_id=#{other.company_id}, requested_by_id=#{other.id} WHERE id=#{record.id}")
    end
  end
  test "revoked source read hides metadata payload audit and existing realtime subscription messages" do
    record = enqueue
    deliver(record)
    event = OutboxEvent.where(company_id: @admin.company_id, event_type: "integration_delivery.created").order(:id).last
    message = { type: event.event_type, id: event.id }
    assert Hrm::RealtimeAuthorization.allowed?(actor: @admin, message: message)
    attempt_event = OutboxEvent.where(company_id: @admin.company_id, event_type: "integration_delivery_attempt.created").last
    assert Hrm::RealtimeAuthorization.allowed?(actor: @admin, message: { type: attempt_event.event_type, id: attempt_event.id })
    token_headers = headers
    deny(@admin, "payroll.exports.read")
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: @admin, message: message)
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: @admin, message: { type: attempt_event.event_type, id: attempt_event.id })
    assert_not_includes Pundit.policy_scope!(@admin, IntegrationDelivery).pluck(:id), record.id
    get "/api/v1/integration/outbound/#{record.id}", headers: token_headers
    assert_response :not_found
    get "/api/v1/integration/outbound/#{record.id}/payload", headers: token_headers
    assert_response :not_found
    audit = Pundit.policy_scope!(@admin, [ :integration, AuditLog ])
    assert_not audit.exists?(record_type: "IntegrationDelivery", record_id: record.id)
    assert_not audit.exists?(record_type: "IntegrationDeliveryAttempt", record_id: record.integration_delivery_attempts.first.id)
    generic = HrmIntegration::Application::Commands::QueueDelivery.new.call(actor: @admin, connection_id: @connection.id, target_key: "partner", idempotency_key: "generic", body: { event_type: "external.notification", payload: {} }.to_json)
    assert Pundit.policy_scope!(@admin, IntegrationDelivery).exists?(generic.id)
    generic_event = OutboxEvent.where(event_type: "integration_delivery.created").order(:id).last
    assert Hrm::RealtimeAuthorization.allowed?(actor: @admin, message: { type: generic_event.event_type, id: generic_event.id })
    assert audit.exists?(record_type: "IntegrationDelivery", record_id: generic.id)
  end
  test "realtime rejects unknown event forged type and foreign outbox identity" do
    enqueue
    event = OutboxEvent.where(event_type: "integration_delivery.created").order(:id).last
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: @admin, message: { type: event.event_type, id: "1" })
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: @admin, message: { type: "integration_delivery.updated", id: event.id })
    other = make_user(:admin, company: Company.create!(code: "REAL#{SecureRandom.hex(4).upcase}", name: "Other"))
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: other, message: { type: event.event_type, id: event.id })
  end
  test "web and API accept source and destination only and retain CSRF Bearer boundaries" do
    get "/api/v1/integration/payroll-exports/#{@source.id}"
    assert_response :unauthorized
    token_headers = headers
    get "/api/v1/integration/payroll-exports/#{@source.id}", headers: token_headers
    assert_response :success
    assert_not_includes response.body, "PRIVATE_PAYROLL_EMPLOYEE"
    post "/api/v1/integration/payroll-exports/#{@source.id}", params: { connection_id: @connection.id, target_key: "partner", body: "FAKE_BODY", company_id: 999, status: "delivered" }, headers: token_headers, as: :json
    assert_response :accepted
    record = IntegrationDelivery.find(response.parsed_body["id"])
    assert_equal "queued", record.status
    assert_equal @admin.company_id, record.company_id
    assert_not_includes record.payload, "FAKE_BODY"
    post "/session", params: { email: @admin.email, password: "StrongPassword123!" }
    get "/integration/payroll-exports/#{@source.id}"
    assert_response :success
    assert_select "a[href='/payroll/exports/#{@source.id}']"
    assert_select "form[action='/integration/payroll-exports/#{@source.id}']"
    old = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    post "/integration/payroll-exports/#{@source.id}", params: { connection_id: @connection.id, target_key: "partner" }
    assert_response :unprocessable_entity
  ensure
    ActionController::Base.allow_forgery_protection = old
  end
  test "typed queue rolls back source delivery audit and outbox on evidence failure" do
    original = Hrm::Container.method(:resolve)
    broken = Object.new
    def broken.append!(**) = raise(IOError, "outbox unavailable")
    resolver = ->(contract) { contract == HrmPlatform::Domain::Repositories::OutboxRepositoryInterface ? broken : original.call(contract) }
    assert_no_difference [ "IntegrationDelivery.count", "AuditLog.count", "OutboxEvent.count" ] do
      Hrm::Container.stub(:resolve, resolver) { assert_raises(IOError) { enqueue } }
    end
  end
  test "generic queue cannot occupy the bridge idempotency namespace" do
    assert_raises(HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload) do
      HrmIntegration::Application::Commands::QueueDelivery.new.call(actor: @admin, connection_id: @connection.id, target_key: "partner",
        idempotency_key: "payroll-v1:claimed", body: { event_type: "external.notification", payload: {} }.to_json)
    end
    assert_equal 0, IntegrationDelivery.count
  end
end
