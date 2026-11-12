require "test_helper"
class OnboardingModuleTest < ActionDispatch::IntegrationTest
  def commands = HrmOnboarding::Application::Commands
  def setup_case
    @admin = make_user(:admin)
    @employee = make_employee
    @record = commands::CreateCase.new.call(actor: @admin, attributes: { employee_id: @employee.id, start_date: Date.current.iso8601 })
  end
  def login(user)
    post "/session", params: { email: user.email, password: "StrongPassword123!" }
  end
  test "creation snapshots checklist and writes audit and outbox atomically" do
    admin = make_user(:admin)
    employee = make_employee
    assert_difference [ "OnboardingCase.count", "AuditLog.count", "OutboxEvent.count" ], 1 do
      record = commands::CreateCase.new.call(actor: admin, attributes: { employee_id: employee.id, start_date: Date.current.iso8601, company_id: 999, status: "completed", checklist: [] })
      assert_equal admin.company_id, record.company_id
      assert_equal "preboarding", record.status
      assert_equal 3, record.checklist.size
      assert(record.checklist.none? { |item| item["done"] })
    end
  end
  test "state machine follows DJI transitions and requires mandatory checklist" do
    setup_case
    assert_raises ActiveRecord::RecordInvalid do
      commands::TransitionCase.new.call(actor: @admin, id: @record.id, status: "completed", lock_version: 0)
    end
    @record = commands::TransitionCase.new.call(actor: @admin, id: @record.id, status: "in_progress", lock_version: 0)
    assert_raises ActiveRecord::RecordInvalid do
      commands::TransitionCase.new.call(actor: @admin, id: @record.id, status: "completed", lock_version: @record.lock_version)
    end
    @record.checklist.each do |item|
      @record = commands::CompleteChecklist.new.call(actor: @admin, id: @record.id, code: item["code"], lock_version: @record.lock_version)
    end
    @record = commands::TransitionCase.new.call(actor: @admin, id: @record.id, status: "completed", lock_version: @record.lock_version)
    assert_equal "completed", @record.status
    assert_raises ActiveRecord::RecordInvalid do
      commands::CompleteChecklist.new.call(actor: @admin, id: @record.id, code: "welcome", lock_version: @record.lock_version)
    end
  end
  test "stale version cannot overwrite a checklist change" do
    setup_case
    commands::CompleteChecklist.new.call(actor: @admin, id: @record.id, code: "welcome", lock_version: 0)
    assert_raises ActiveRecord::StaleObjectError do
      commands::TransitionCase.new.call(actor: @admin, id: @record.id, status: "in_progress", lock_version: 0)
    end
    assert_equal "preboarding", @record.reload.status
  end
  test "own scope, cross-company IDs and revoked permissions fail closed" do
    setup_case
    other = make_user(:admin, company: Company.create!(code: "ERP#{SecureRandom.hex(4).upcase}", name: "Other"))
    assert_raises ActiveRecord::RecordNotFound do
      commands::CreateCase.new.call(actor: other, attributes: { employee_id: @employee.id, start_date: Date.current.iso8601 })
    end
    assert_raises ActiveRecord::RecordNotFound do
      commands::TransitionCase.new.call(actor: other, id: @record.id, status: "in_progress", lock_version: 0)
    end
    login(@employee.user)
    get "/onboarding/cases/#{@record.id}"
    assert_response :success
    patch "/onboarding/cases/#{@record.id}/status", params: { status: "in_progress", lock_version: 0 }
    assert_response :forbidden
    @employee.user.user_permissions.create!(permission: Permission.find_by!(key: "onboarding.read"), granted: false)
    get "/onboarding/cases/#{@record.id}"
    assert_response :forbidden
  end
  test "HTTP board, form and API preserve validation, locking and authentication" do
    setup_case
    login(@admin)
    get "/onboarding/cases"
    assert_response :success
    assert_select "a[href='/onboarding/cases/#{@record.id}']", count: 1
    assert_select "h2", text: "Trước ngày nhận việc"
    get "/onboarding/cases/new"
    assert_response :success
    post "/onboarding/cases", params: { onboarding_case: { employee_id: @employee.id, start_date: "2026-02-31" } }
    assert_response :unprocessable_entity
    post "/onboarding/cases", params: { onboarding_case: "invalid" }
    assert_response :bad_request
    headers = { "Authorization" => "Bearer #{ApiToken.issue!(@admin)}" }
    get "/api/v1/onboarding/cases"
    assert_response :unauthorized
    get "/api/v1/onboarding/cases", headers: headers
    assert_response :success
    assert_equal @record.id, response.parsed_body.fetch("data").first.fetch("id")
    patch "/api/v1/onboarding/cases/#{@record.id}/status", params: { status: "in_progress", lock_version: 0 }, headers: headers
    assert_response :success
    patch "/api/v1/onboarding/cases/#{@record.id}/status", params: { status: "blocked", lock_version: 0 }, headers: headers
    assert_response :conflict
  end
  test "MySQL composite foreign key rejects cross-company employee" do
    setup_case
    other = Company.create!(code: "ERP#{SecureRandom.hex(4).upcase}", name: "Other")
    assert_raises ActiveRecord::InvalidForeignKey do
      OnboardingCase.insert_all!([ { company_id: other.id, employee_id: @employee.id, start_date: Date.current, status: "preboarding", checklist: [], created_at: Time.current, updated_at: Time.current } ]) # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    end
  end
  test "duplicate start date and malformed IDs cannot create another case" do
    setup_case
    assert_no_difference "OnboardingCase.count" do
      assert_raises ActiveRecord::RecordInvalid do
        commands::CreateCase.new.call(actor: @admin, attributes: { employee_id: @employee.id, start_date: Date.current.iso8601 })
      end
      assert_raises ActiveRecord::RecordNotFound do
        commands::CreateCase.new.call(actor: @admin, attributes: { employee_id: { bad: 1 }, start_date: Date.current.iso8601 })
      end
    end
  end
  test "employee with onboarding history cannot be deleted" do
    setup_case
    assert_no_difference [ "Employee.count", "OnboardingCase.count", "AuditLog.count", "OutboxEvent.count" ] do
      result = HrmWorkforce::Application::Commands::DeleteEmployee.new.call(actor: @admin, record: @employee)
      assert_not result
    end
    assert @employee.errors.any?
  end
end
