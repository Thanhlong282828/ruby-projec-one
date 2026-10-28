require "test_helper"
class CompanyPermissionsTest < ActionDispatch::IntegrationTest
  def headers_for(user) = { "Authorization" => "Bearer #{ApiToken.issue!(user)}" }
  test "company admin sees management screens and saves account permissions" do
    admin = make_user(:admin)
    employee = make_user
    post "/session", params: { email: admin.email, password: "StrongPassword123!" }
    ["/manage/company", "/manage/accounts", "/manage/roles", "/manage/accounts/#{employee.id}", "/manage/accounts/#{admin.id}"].each do |path|
      get path
      assert_response :success, path
    end
    patch "/manage/accounts/#{employee.id}", params: { account: { role: "manager", active: "1", permission_overrides: { "payroll.read" => "grant" } } }
    assert_redirected_to administration_accounts_path
    assert employee.reload.allowed?("payroll.read")
    patch "/manage/company", params: { company: { name: "Updated Company", code: "IGNORED" } }
    assert_redirected_to administration_company_path
    assert_equal "Updated Company", admin.company.reload.name
    assert_equal "TEST", admin.company.code
  end
  test "employee cannot reach company account or role management via web or API" do
    employee = make_user
    post "/session", params: { email: employee.email, password: "StrongPassword123!" }
    %w[/manage/company /manage/accounts /manage/roles].each { |path| get path; assert_response :forbidden }
    %w[/api/v1/company /api/v1/accounts /api/v1/roles].each { |path| get path, headers: headers_for(employee); assert_response :forbidden }
  end
  test "API administrator is company scoped and cannot write another company account or role" do
    admin = make_user(:admin)
    company = Company.create!(code: "FOREIGN", name: "Foreign")
    other = make_user(:admin, company: company)
    headers = headers_for(admin)
    get "/api/v1/accounts", headers: headers
    assert_response :success
    assert_not_includes response.parsed_body["data"].map { |row| row["id"] }, other.id
    patch "/api/v1/accounts/#{other.id}", params: { account: { role: "employee" } }, headers: headers, as: :json
    assert_response :not_found
    patch "/api/v1/roles/#{company.company_roles.first.id}", params: { role: { permission_keys: [] } }, headers: headers, as: :json
    assert_response :not_found
  end
  test "revoked permissions affect an already issued API token without logout" do
    user = make_user
    make_employee(user)
    headers = headers_for(user)
    get "/api/v1/employees", headers: headers
    assert_response :success
    user.user_permissions.create!(permission: Permission.find_by!(key: "employees.read"), granted: false)
    get "/api/v1/employees", headers: headers
    assert_response :forbidden
  end
  test "foreign company query headers and payload cannot change request tenant" do
    admin = make_user(:admin)
    own = make_employee
    company = Company.create!(code: "FOREIGN", name: "Foreign")
    other = make_employee(make_user(:employee, company: company))
    headers = headers_for(admin).merge("X-Company-ID" => company.id.to_s)
    get "/api/v1/employees", params: { company_id: company.id }, headers: headers
    assert_response :success
    assert_equal [own.id], response.parsed_body["data"].map { |row| row["id"] }
    get "/api/v1/employees/#{other.id}", headers: headers
    assert_response :not_found
    post "/api/v1/departments", params: { department: { code: "NEW", name: "Own", company_id: company.id } }, headers: headers, as: :json
    assert_response :created
    assert_equal admin.company_id, Department.find(response.parsed_body["data"]["id"]).company_id
  end
  test "inactive company cannot authenticate or use an existing token" do
    user = make_user
    headers = headers_for(user)
    user.company.update!(active: false)
    get "/api/v1/employees", headers: headers
    assert_response :unauthorized
    post "/api/v1/session", params: { email: user.email, password: "StrongPassword123!" }, as: :json
    assert_response :unauthorized
  end
  test "invalid self permission change returns a validation response and keeps admin access" do
    admin = make_user(:admin)
    patch "/api/v1/accounts/#{admin.id}", params: { account: { role: "employee" } }, headers: headers_for(admin), as: :json
    assert_response :unprocessable_entity
    assert admin.reload.allowed?("accounts.manage")
  end
  test "web create department and candidate keep controller constructors intact" do
    admin = make_user(:admin)
    post "/session", params: { email: admin.email, password: "StrongPassword123!" }
    post "/departments", params: { department: { code: "WEB", name: "Web" } }
    assert_response :redirect
    post "/candidates", params: { candidate: { full_name: "Candidate", email: "candidate-web@example.test", position: "Engineer", stage: "applied" } }
    assert_response :redirect
    assert_equal admin.company_id, Candidate.find_by!(email: "candidate-web@example.test").company_id
  end
  test "admin creates and assigns a custom MySQL role using REST endpoints" do
    admin = make_user(:admin)
    employee = make_user
    headers = headers_for(admin)
    post "/api/v1/roles", params: { role: { key: "recruiter", name: "Tuyển dụng", permission_keys: %w[dashboard.view recruitment.read recruitment.write] } }, headers: headers, as: :json
    assert_response :created
    role_id = response.parsed_body["data"]["id"]
    assert_equal admin.company_id, CompanyRole.find(role_id).company_id
    patch "/api/v1/accounts/#{employee.id}", params: { account: { role: "recruiter" } }, headers: headers, as: :json
    assert_response :no_content
    assert employee.reload.allowed?("recruitment.write")
    assert_not employee.allowed?("payroll.read")
  end

  test "invalid account role or null active status is rejected without changing the account" do
    admin = make_user(:admin)
    employee = make_user
    headers = headers_for(admin)
    patch "/api/v1/accounts/#{employee.id}", params: { account: { role: "unknown_superadmin" } }, headers: headers, as: :json
    assert_response :unprocessable_entity
    assert employee.reload.employee?
    patch "/api/v1/accounts/#{employee.id}", params: { account: { active: nil } }, headers: headers, as: :json
    assert_response :unprocessable_entity
    assert employee.reload.active?
  end

  test "role case and trailing spaces cannot bypass protected admin permissions" do
    admin = make_user(:admin)
    employee = make_user
    patch "/api/v1/accounts/#{employee.id}", params: { account: { role: "ADMIN ", permission_overrides: { "roles.manage" => "deny" } } }, headers: headers_for(admin), as: :json
    assert_response :unprocessable_entity
    assert employee.reload.employee?
    assert_not employee.allowed?("accounts.manage")
  end

end
