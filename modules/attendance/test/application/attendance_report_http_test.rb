require "test_helper"
class AttendanceReportHttpTest < ActionDispatch::IntegrationTest
  def setup
    super
    @employee = make_employee
    @actor = @employee.user
    @headers = { "Authorization" => "Bearer #{ApiToken.issue!(@actor)}" }
    @params = { from: Date.current.to_s, to: Date.current.to_s }
  end
  test "web report requires login and renders employee scoped data" do
    get "/attendances/report"
    assert_redirected_to new_session_path
    post "/session", params: { email: @actor.email, password: "StrongPassword123!" }
    get "/attendances/report", params: @params
    assert_response :success
    assert_select "h1", "Báo cáo chấm công."
    assert_select "input[name=from]"
  end
  test "API authenticates and ignores client company selection" do
    get "/api/v1/attendances/report", params: @params
    assert_response :unauthorized
    HrmAttendance::Application::Commands::CheckIn.new.call(actor: @actor)
    get "/api/v1/attendances/report", params: @params.merge(company_id: -1), headers: @headers
    assert_response :success
    assert_equal 1, response.parsed_body.dig("summary", "total")
    assert_equal "open", response.parsed_body.fetch("rows").first.fetch("status")
    assert_not response.parsed_body.to_s.include?("salary_cents")
  end
  test "invalid dates produce a controlled 422 on web and API" do
    get "/api/v1/attendances/report", params: { from: "not-a-date" }, headers: @headers
    assert_response :unprocessable_entity
    assert_equal "invalid_period", response.parsed_body["error"]
    post "/session", params: { email: @actor.email, password: "StrongPassword123!" }
    get "/attendances/report", params: { from: "2026-02-30" }
    assert_response :unprocessable_entity
  end
  test "permission deny is enforced for an already issued API token" do
    UserPermission.create!(user: @actor, permission: Permission.find_by!(key: "attendance.read"), granted: false)
    get "/api/v1/attendances/report", params: @params, headers: @headers
    assert_response :forbidden
  end
end
