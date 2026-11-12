require "test_helper"
require "minitest/mock"
class PayrollExportTest < ActionDispatch::IntegrationTest
  def setup
    super
    @admin = make_user(:admin)
    @employee = make_employee(employee_code: "EMP-PRIVATE", full_name: "PRIVATE_FULL_NAME", bank_account: "PRIVATE_BANK", national_id: "PRIVATE_ID")
    @run = Payroll::BuildRun.call(period: Date.current, actor: @admin)
    Payroll::FinalizeRun.call(run: @run, actor: @admin)
  end
  def create_export(actor: @admin, run: @run)
    HrmPayroll::Application::Commands::CreateExport.new.call(actor: actor, pay_run_id: run.id)
  end
  def download(record, actor: @admin)
    HrmPayroll::Application::Commands::DownloadExport.new.call(actor: actor, id: record.id)
  end
  def grant(user, *keys)
    keys.each { |key| user.user_permissions.create!(permission: Permission.find_by!(key: key), granted: true) }
  end
  def api_headers(user = @admin) = { "Authorization" => "Bearer #{ApiToken.issue!(user)}" }
  def login(user = @admin)
    post "/session", params: { email: user.email, password: "StrongPassword123!" }
  end
  test "snapshot creation is idempotent encrypted and atomic with audit outbox" do
    assert_difference [ "PayrollExport.count", "AuditLog.count", "OutboxEvent.count" ], 1 do
      @export = create_export
    end
    assert_no_difference [ "PayrollExport.count", "AuditLog.count", "OutboxEvent.count" ] do
      assert_equal @export.id, create_export.id
    end
    raw = PayrollExport.connection.select_value("SELECT artifact FROM payroll_exports WHERE id=#{@export.id.to_i}")
    assert_not_includes raw, "EMP-PRIVATE"
    assert_not_includes @export.to_json, "EMP-PRIVATE"
    assert_not @export.public_attributes.key?("artifact")
    assert_equal "mediumtext", PayrollExport.columns_hash.fetch("artifact").sql_type
  end
  test "download uses original immutable bytes and excludes personal identifiers" do
    export = create_export
    original = export.artifact
    @employee.update!(employee_code: "CHANGED", salary_cents: 30_000_000)
    assert_raises(ActiveRecord::ReadOnlyRecord) { @run.payslips.first.update!(gross_cents: 99_000_000, net_cents: 99_000_000) }
    @run.payslips.first.update_columns(gross_cents: 99_000_000, net_cents: 99_000_000) # rubocop:disable Rails/SkipsModelValidations -- Deliberate SQL corruption still cannot change an already encrypted artifact.
    result = download(export)
    assert_equal original, result[:bytes]
    assert_includes result[:bytes], "EMP-PRIVATE"
    %w[PRIVATE_FULL_NAME PRIVATE_BANK PRIVATE_ID CHANGED 99000000].each { |value| assert_not_includes result[:bytes], value }
    assert_match(/\Apayroll-[0-9]{4}-[0-9]{2}-[0-9a-f-]{36}\.csv\z/, result[:filename])
    assert_raises(ActiveRecord::ReadOnlyRecord) { export.update!(employee_count: 7) }
    assert_raises(ActiveRecord::RecordNotDestroyed) { export.destroy! }
    assert PayrollExport.exists?(export.id)
    assert_equal "allowed", export.payroll_export_accesses.last.result
  end
  test "download permission is separate and revocation applies to existing token" do
    export = create_export
    reader = make_user(:employee)
    grant(reader, "payroll.read", "payroll.exports.read")
    headers = api_headers(reader)
    get "/api/v1/payroll/exports/#{export.id}", headers: headers
    assert_response :success
    assert_not_includes response.body, "EMP-PRIVATE"
    get "/api/v1/payroll/exports/#{export.id}/download", headers: headers
    assert_response :forbidden
    grant(reader, "payroll.exports.download")
    get "/api/v1/payroll/exports/#{export.id}/download", headers: headers
    assert_response :success
    assert_includes response.body, "EMP-PRIVATE"
    reader.user_permissions.find_by!(permission: Permission.find_by!(key: "payroll.exports.download")).update!(granted: false)
    assert_no_difference "PayrollExportAccess.count" do
      get "/api/v1/payroll/exports/#{export.id}/download", headers: headers
      assert_response :forbidden
    end
    assert_includes response.headers["Cache-Control"], "no-store"
  end
  test "company scope and composite foreign keys reject foreign source access and links" do
    export = create_export
    other = make_user(:admin, company: Company.create!(code: "EXP#{SecureRandom.hex(4).upcase}", name: "Other"))
    assert_raises(ActiveRecord::RecordNotFound) { create_export(actor: other) }
    assert_raises(ActiveRecord::RecordNotFound) { download(export, actor: other) }
    result = HrmPayroll::Application::Queries::ExportWorkspace.new.call(actor: other)
    assert_empty result[:records]
    assert_empty result[:eligible_runs]
    assert_equal 0, result[:count]
    assert_raises ActiveRecord::InvalidForeignKey do
      PayrollExportAccess.insert_all!([ { company_id: other.company_id, payroll_export_id: export.id, actor_id: other.id, result: "allowed", created_at: Time.current, updated_at: Time.current } ]) # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    end
  end
  test "draft empty malformed and invalid monetary snapshots fail without export writes" do
    draft = PayRun.create!(company: @admin.company, period: Date.current + 1.month, created_by: @admin)
    assert_raises(HrmPayroll::Domain::Services::PayrollCsv::InvalidSource) { create_export(run: draft) }
    draft.update!(status: "finalized", finalized_at: Time.current)
    assert_raises(HrmPayroll::Domain::Services::PayrollCsv::InvalidSource) { create_export(run: draft) }
    @run.payslips.first.update_columns(net_cents: 1) # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    assert_no_difference "PayrollExport.count" do
      assert_raises(HrmPayroll::Domain::Services::PayrollCsv::InvalidSource) { create_export }
    end
  end
  test "integrity failure blocks bytes and commits safe access record audit and outbox" do
    export = create_export
    PayrollExport.where(id: export.id).update_all(checksum: "0" * 64) # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    assert_difference [ "PayrollExportAccess.count", "AuditLog.count", "OutboxEvent.count" ], 1 do
      assert_raises(HrmPayroll::Domain::Services::PayrollCsv::IntegrityError) { download(export) }
    end
    assert_equal "integrity_failed", export.payroll_export_accesses.last.result
    get "/api/v1/payroll/exports/#{export.id}/download", headers: api_headers
    assert_response :conflict
    assert_not_includes response.body, "EMP-PRIVATE"
  end
  test "corrupt ciphertext is handled without exposing content" do
    export = create_export
    PayrollExport.connection.execute("UPDATE payroll_exports SET artifact='broken-ciphertext' WHERE id=#{export.id.to_i}")
    assert_raises(HrmPayroll::Domain::Services::PayrollCsv::IntegrityError) { download(export) }
    assert_equal "integrity_failed", export.payroll_export_accesses.last.result
  end
  test "artifact or access outbox failure rolls back and never returns bytes" do
    original = Hrm::Container.method(:resolve)
    broken = Object.new
    def broken.append!(**) = raise(IOError, "outbox unavailable")
    resolver = ->(contract) { contract == HrmPlatform::Domain::Repositories::OutboxRepositoryInterface ? broken : original.call(contract) }
    assert_no_difference [ "PayrollExport.count", "AuditLog.count", "OutboxEvent.count" ] do
      Hrm::Container.stub(:resolve, resolver) { assert_raises(IOError) { create_export } }
    end
    export = create_export
    assert_no_difference [ "PayrollExportAccess.count", "AuditLog.count", "OutboxEvent.count" ] do
      Hrm::Container.stub(:resolve, resolver) { assert_raises(IOError) { download(export) } }
    end
  end
  test "web retains CSRF while API allows only source id and server generated artifact" do
    login
    old = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    post "/payroll/exports", params: { pay_run_id: @run.id }
    assert_response :unprocessable_entity
    assert_equal 0, PayrollExport.count
    ActionController::Base.allow_forgery_protection = old
    post "/api/v1/payroll/exports", params: { pay_run_id: @run.id, company_id: 999, artifact: "ATTACKER_DATA", filename: "../../escape.csv" }, headers: api_headers, as: :json
    assert_response :created
    id = response.parsed_body["id"]
    assert_not response.parsed_body.key?("artifact")
    assert_no_difference "PayrollExport.count" do
      post "/api/v1/payroll/exports", params: { pay_run_id: @run.id }, headers: api_headers, as: :json
      assert_response :ok
      assert_equal id, response.parsed_body["id"]
    end
    get "/api/v1/payroll/exports/#{id}/download", headers: api_headers
    assert_response :success
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_not_includes response.body, "ATTACKER_DATA"
    assert_not_includes response.headers["Content-Disposition"], "escape.csv"
  ensure
    ActionController::Base.allow_forgery_protection = old
  end
  test "authentication metadata query and malformed filters fail safely" do
    get "/api/v1/payroll/exports"
    assert_response :unauthorized
    login
    get "/api/v1/payroll/exports"
    assert_response :unauthorized
    headers = api_headers
    [ { before: "0" }, { before: "9223372036854775808" }, { period: "2026-13" }, { period: { bad: true } }, { before: "1 OR 1=1" } ].each do |filter|
      get "/api/v1/payroll/exports", params: filter, headers: headers
      assert_response :bad_request
    end
    export = create_export
    get "/payroll/exports/#{export.id}"
    assert_response :success
    assert_select "a[href='/pay_runs/#{@run.id}']"
    assert_select "a[href='/payroll/exports/#{export.id}/download']"
    assert_not_includes response.body, "EMP-PRIVATE"
  end
  test "source options and navigation require both payroll and export read grants" do
    login
    get "/payroll/exports"
    assert_response :success
    assert_select "option[value='#{@run.id}']"
    viewer = make_user(:employee)
    grant(viewer, "payroll.exports.read")
    login(viewer)
    get "/"
    assert_response :success
    assert_select "a[href='/payroll/exports']", count: 0
    assert_raises(Pundit::NotAuthorizedError) { HrmPayroll::Application::Queries::ExportWorkspace.new.call(actor: viewer) }
    grant(viewer, "payroll.read")
    get "/"
    assert_response :success
    assert_select "a[href='/payroll/exports']", minimum: 1
  end
end
