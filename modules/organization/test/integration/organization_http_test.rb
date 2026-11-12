require "test_helper"
class OrganizationHttpTest < ActionDispatch::IntegrationTest
  def setup
    super
    @admin = make_user(:admin)
    @headers = { "Authorization" => "Bearer #{ApiToken.issue!(@admin)}" }
  end
  def login
    post "/session", params: { email: @admin.email, password: "StrongPassword123!" }
  end
  test "all organization web pages use the current layout and permission guarded forms" do
    login
    %w[cost-centers organization-units job-positions employee-assignments].each do |resource|
      get "/organization/#{resource}"
      assert_response :success
      get "/organization/#{resource}/new"
      assert_response :success
      assert_select "form[action='/organization/#{resource}'][method='post']"
    end
    get "/organization/tree"
    assert_response :success
    get "/organization/headcount"
    assert_response :success
  end
  test "web CRUD validation and export work without direct controller persistence" do
    login
    post "/organization/cost-centers", params: { record: { code: "WEB", name: "Web" } }
    record = CostCenter.find_by!(company_id: @admin.company_id, code: "WEB")
    assert_redirected_to "/organization/cost-centers/#{record.id}"
    get "/organization/cost-centers/#{record.id}"
    assert_response :success
    get "/organization/cost-centers/#{record.id}/edit"
    assert_response :success
    patch "/organization/cost-centers/#{record.id}", params: { record: { annual_budget: -1 } }
    assert_response :unprocessable_entity
    assert_equal 0, record.reload.annual_budget
    patch "/organization/cost-centers/#{record.id}", params: { record: { name: "Updated" } }
    assert_redirected_to "/organization/cost-centers/#{record.id}"
    get "/organization/cost-centers/export"
    assert_response :success
    assert_includes response.media_type, "text/csv"
    delete "/organization/cost-centers/#{record.id}"
    assert_redirected_to "/organization/cost-centers"
  end
  test "API CRUD rejects unknown fields and cross company ids" do
    foreign = Company.create!(code: "HTTPFOREIGN", name: "Foreign")
    post "/api/v1/organization/cost-centers", headers: @headers, params: { record: { code: "API", name: "Own", company_id: foreign.id } }, as: :json
    assert_response :created
    id = response.parsed_body["data"]["id"]
    assert_equal @admin.company_id, response.parsed_body["data"]["company_id"]
    get "/api/v1/organization/cost-centers/#{id}", headers: @headers
    assert_response :success
    other = CostCenter.create!(company: foreign, code: "FOREIGN", name: "Foreign")
    patch "/api/v1/organization/cost-centers/#{other.id}", headers: @headers, params: { record: { name: "Leak" } }, as: :json
    assert_response :not_found
    get "/api/v1/organization/cost-centers", headers: @headers
    assert_equal([ id ], response.parsed_body["data"].pluck("id"))
    patch "/api/v1/organization/cost-centers/#{id}", headers: @headers, params: { record: { name: "Updated" } }, as: :json
    assert_response :success
    delete "/api/v1/organization/cost-centers/#{id}", headers: @headers
    assert_response :no_content
  end
  test "authentication permission revoke and resource spoofing are enforced" do
    get "/api/v1/organization/cost-centers"
    assert_response :unauthorized
    user = make_user
    headers = { "Authorization" => "Bearer #{ApiToken.issue!(user)}" }
    get "/api/v1/organization/cost-centers", headers: headers
    assert_response :forbidden
    @admin.user_permissions.create!(permission: Permission.find_by!(key: "cost_centers.read"), granted: false)
    get "/api/v1/organization/cost-centers", headers: @headers
    assert_response :forbidden
    get "/api/v1/organization/cost-centers", headers: @headers, params: { resource: "employee_assignments" }
    assert_response :forbidden
  end
  test "API tree and headcount are company scoped with no employee profile fields" do
    get "/api/v1/organization/tree", headers: @headers
    assert_response :success
    assert_equal [], response.parsed_body["data"]
    get "/api/v1/organization/headcount", headers: @headers
    assert_response :success
  end
end
