require "test_helper"
class BranchesTest < ActionDispatch::IntegrationTest
  test "a company owns multiple real organization branches with scoped web API and cross company FK" do
    admin = make_user(:admin)
    other = make_user(:admin, company: Company.create!(code: "BR#{SecureRandom.hex(4).upcase}", name: "Other"))
    branch = ->(actor, code) { HrmOrganization::Application::Commands::CreateRecord.new.call(actor: actor, resource: "organization_units", attributes: { code: code, name: code, unit_type: "branch", effective_from: Date.current, headcount_limit: 0 }) }
    first = branch.call(admin, "FIRST")
    second = branch.call(admin, "SECOND")
    foreign = branch.call(other, "FOREIGN")
    result = HrmOrganization::Application::Queries::Branches.new.call(actor: admin)
    assert_equal 2, result[:total]
    assert_equal [ first.id, second.id ].sort, result[:records].map(&:id).sort
    assert_not_includes result[:records].map(&:id), foreign.id
    assert_raises(ActiveRecord::RecordInvalid) do
      HrmOrganization::Application::Commands::CreateRecord.new.call(actor: admin, resource: "organization_units", attributes: { code: "BAD", name: "Bad", unit_type: "branch", parent_id: foreign.id, effective_from: Date.current })
    end
    headers = { "Authorization" => "Bearer #{ApiToken.issue!(admin)}" }
    post "/api/v1/organization/branches", params: { branch: { code: "THIRD", name: "Third", effective_from: Date.current.to_s, headcount_limit: 0, unit_type: "company", company_id: other.company_id } }, headers: headers, as: :json
    assert_response :created
    assert_equal admin.company_id, response.parsed_body["company_id"]
    assert_equal "branch", response.parsed_body["unit_type"]
    assert_equal 3, admin.company.branches.count
    post "/session", params: { email: admin.email, password: "StrongPassword123!" }
    get "/organization/branches"
    assert_response :success
    assert_select "a[href='/organization/organization-units/#{first.id}']"
    assert_not_includes response.body, "FOREIGN"
    viewer = make_user(:employee)
    assert_raises(Pundit::NotAuthorizedError) { HrmOrganization::Application::Queries::Branches.new.call(actor: viewer) }
  end
end
