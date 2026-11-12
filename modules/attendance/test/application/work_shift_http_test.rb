require "test_helper"
class WorkShiftHttpTest < ActionDispatch::IntegrationTest
  def setup
    super
    @admin = make_user(:admin)
    @headers = { "Authorization" => "Bearer #{ApiToken.issue!(@admin)}" }
    @fields = { code: "DAY", name: "Ca ngày", start_time: "08:00", end_time: "17:00", unpaid_break_minutes: 60 }
  end
  def create_shift
    post "/api/v1/work_shifts", params: { work_shift: @fields }, headers: @headers, as: :json
    assert_response :created
    response.parsed_body.fetch("id")
  end
  test "web forms and safe validation errors render" do
    get "/work_shifts"
    assert_redirected_to new_session_path
    post "/session", params: { email: @admin.email, password: "StrongPassword123!" }
    get "/work_shifts/new"
    assert_response :success
    assert_select "input[name='work_shift[start_time]']"
    post "/work_shifts", params: { work_shift: @fields.merge(start_time: "99:99") }
    assert_response :unprocessable_entity
    id = create_shift
    [ "/work_shifts", "/work_shifts/#{id}", "/work_shifts/#{id}/edit" ].each do |path|
      get path
      assert_response :success
    end
  end
  test "API CRUD enforces optimistic version and excludes client company" do
    post "/api/v1/work_shifts", params: { work_shift: @fields.merge(company_id: -1, start_minute: 0) }, headers: @headers, as: :json
    assert_response :created
    id = response.parsed_body.fetch("id")
    assert_equal "08:00", response.parsed_body["start_time"]
    assert_equal @admin.company_id, WorkShift.find(id).company_id
    patch "/api/v1/work_shifts/#{id}", params: { work_shift: { name: "Changed", lock_version: 0 } }, headers: @headers, as: :json
    assert_response :success
    patch "/api/v1/work_shifts/#{id}", params: { work_shift: { name: "Stale", lock_version: 0 } }, headers: @headers, as: :json
    assert_response :conflict
    delete "/api/v1/work_shifts/#{id}", params: { lock_version: 1 }, headers: @headers, as: :json
    assert_response :no_content
  end
  test "API deny is enforced for existing token and cross company ID returns 404" do
    id = create_shift
    get "/api/v1/work_shifts"
    assert_response :unauthorized
    company = Company.create!(code: "OTHER", name: "Other")
    token = ApiToken.issue!(make_user(:admin, company: company))
    get "/api/v1/work_shifts/#{id}", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :not_found
    @admin.user_permissions.create!(permission: Permission.find_by!(key: "work_shifts.read"), granted: false)
    get "/api/v1/work_shifts", headers: @headers
    assert_response :forbidden
  end
  test "preview validates source id and returns only a read only calculation" do
    id = create_shift
    get "/api/v1/work_shifts/#{id}/preview", params: { attendance_id: [ 1 ] }, headers: @headers
    assert_response :not_found
    row = make_employee.attendances.create!(work_date: Date.current, checked_in_at: Time.current)
    get "/api/v1/work_shifts/#{id}/preview", params: { attendance_id: row.id }, headers: @headers
    assert_response :success
    assert response.parsed_body["preview_only"]
    assert_equal "incomplete", response.parsed_body.dig("result", "status")
    assert_not response.parsed_body.to_s.include?("salary_cents")
    post "/session", params: { email: @admin.email, password: "StrongPassword123!" }
    get "/work_shifts/#{id}/preview", params: { attendance_id: row.id }
    assert_response :success
    assert_select "h1", "Xem thử theo ca."
  end
end
