require "test_helper"
class ApiTest < ActionDispatch::IntegrationTest
  def token_headers(user)
    { "Authorization" => "Bearer #{ApiToken.issue!(user)}" }
  end
  test "anonymous API calls are rejected" do
    get "/api/v1/employees"
    assert_response :unauthorized
  end
  test "employee sees only own record and cannot write or view others" do
    own = make_employee
    other = make_employee
    headers = token_headers(own.user)
    get "/api/v1/employees", headers: headers
    assert_response :success
    assert_equal [own.id], response.parsed_body["data"].map { |item| item["id"] }
    assert_not response.parsed_body["data"].first.key?("salary_cents")
    get "/api/v1/employees/#{other.id}", headers: headers
    assert_response :not_found
    patch "/api/v1/employees/#{own.id}", params: { employee: { salary_cents: 1 } }, headers: headers, as: :json
    assert_response :forbidden
  end
  test "admin creates and validates employees" do
    admin = make_user(:admin)
    department = make_employee.department
    headers = token_headers(admin)
    post "/api/v1/employees", params: { employee: { employee_code: "API-001", full_name: "API Person", email: "api@example.test", job_title: "Engineer", hired_on: "2026-10-25", department_id: department.id, salary_cents: 10000000 } }, headers: headers, as: :json
    assert_response :created
    post "/api/v1/employees", params: { employee: { full_name: "Incomplete" } }, headers: headers, as: :json
    assert_response :unprocessable_entity
  end
  test "token authentication and revocation" do
    user = make_user
    post "/api/v1/session", params: { email: user.email, password: "StrongPassword123!" }, as: :json
    assert_response :created
    headers = { "Authorization" => "Bearer #{response.parsed_body.fetch('token')}" }
    delete "/api/v1/session", headers: headers
    assert_response :no_content
    get "/api/v1/employees", headers: headers
    assert_response :unauthorized
  end
  test "deactivated users lose access" do
    user = make_user
    headers = token_headers(user)
    user.update!(active: false)
    get "/api/v1/employees", headers: headers
    assert_response :unauthorized
  end
  test "mass assignment cannot grant role via employee API" do
    admin = make_user(:admin)
    employee = make_employee
    patch "/api/v1/employees/#{employee.id}", params: { employee: { full_name: "Updated", role: "admin", user_id: admin.id } }, headers: token_headers(admin), as: :json
    assert_response :success
    assert employee.reload.user.employee?
  end
  test "REST department create update delete" do
    headers = token_headers(make_user(:admin))
    post "/api/v1/departments", params: { department: { code: "API", name: "API team" } }, headers: headers, as: :json
    assert_response :created
    id = response.parsed_body["data"]["id"]
    patch "/api/v1/departments/#{id}", params: { department: { name: "New API team" } }, headers: headers, as: :json
    assert_response :success
    delete "/api/v1/departments/#{id}", headers: headers
    assert_response :no_content
  end
end
