require "test_helper"
class ShiftAssignmentHttpTest < ActionDispatch::IntegrationTest
  def setup
    super
    @admin=make_user(:admin)
    @employee=make_employee
    @shift=HrmAttendance::Application::Commands::CreateWorkShift.new.call(actor: @admin, attributes: { code: "DAY", name: "Day", start_time: "08:00", end_time: "17:00" })
    @headers={ "Authorization"=>"Bearer #{ApiToken.issue!(@admin)}" }
    @fields={ employee_id: @employee.id, work_shift_id: @shift.id, effective_from: Date.current.to_s }
  end
  def create_assignment
    post "/api/v1/shift_assignments", params: { shift_assignment: @fields.merge(company_id: -1, shift_snapshot: { start_minute: 0 }) }, headers: @headers, as: :json
    assert_response :created
    response.parsed_body.fetch("id")
  end
  test "API create snapshot and end update preserve allowlist and version" do
    id=create_assignment
    assert_equal 480, response.parsed_body.dig("shift_snapshot", "start_minute")
    assert_equal @admin.company_id, EmployeeShiftAssignment.find(id).company_id
    patch "/api/v1/shift_assignments/#{id}", params: { shift_assignment: { effective_to: Date.current.to_s, lock_version: 0 } }, headers: @headers, as: :json
    assert_response :success
    patch "/api/v1/shift_assignments/#{id}", params: { shift_assignment: { effective_to: Date.current.to_s, lock_version: 0 } }, headers: @headers, as: :json
    assert_response :conflict
    delete "/api/v1/work_shifts/#{@shift.id}", params: { lock_version: 0 }, headers: @headers, as: :json
    assert_response :conflict
  end
  test "web forms show schedule with protected source links" do
    id=create_assignment
    get "/shift_assignments"
    assert_redirected_to new_session_path
    post "/session", params: { email: @admin.email, password: "StrongPassword123!" }
    [ "/shift_assignments", "/shift_assignments/new", "/shift_assignments/#{id}", "/shift_assignments/#{id}/edit", "/shift_assignments/schedule" ].each do |path|
      get path
      assert_response :success, path
    end
    get "/shift_assignments/schedule", params: { employee_id: @employee.id, from: Date.current.to_s, to: Date.current.to_s }
    assert_response :success
    assert_select "a[href='/shift_assignments/#{id}']"
  end
  test "API auth scope and malformed IDs dates fail closed" do
    id=create_assignment
    get "/api/v1/shift_assignments"
    assert_response :unauthorized
    own=make_user
    token={ "Authorization"=>"Bearer #{ApiToken.issue!(own)}" }
    get "/api/v1/shift_assignments/#{id}", headers: token
    assert_response :not_found
    get "/api/v1/shift_assignments/schedule", params: { employee_id: { bad: 1 } }, headers: @headers
    assert_response :not_found
    get "/api/v1/work_shifts/#{@shift.id}/preview", params: { attendance_id: { bad: 1 } }, headers: @headers
    assert_response :not_found
    get "/api/v1/shift_assignments/schedule", params: { from: "bad" }, headers: @headers
    assert_response :unprocessable_entity
    @admin.user_permissions.create!(permission: Permission.find_by!(key: "shift_assignments.read_all"), granted: false)
    @admin.user_permissions.create!(permission: Permission.find_by!(key: "shift_assignments.read"), granted: false)
    get "/api/v1/shift_assignments", headers: @headers
    assert_response :forbidden
  end
  test "canonical attendance detail preserves ownership" do
    row=@employee.attendances.create!(work_date: Date.current, checked_in_at: Time.current)
    post "/session", params: { email: @employee.user.email, password: "StrongPassword123!" }
    get "/attendances/#{row.id}"
    assert_response :success
    other=make_employee.attendances.create!(work_date: Date.current, checked_in_at: Time.current)
    get "/attendances/#{other.id}"
    assert_response :not_found
  end
end
