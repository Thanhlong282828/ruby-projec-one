require "test_helper"

class BranchDirectoryTest < ActionDispatch::IntegrationTest
  def branch(actor, code, name: code, from: Date.current, to: nil)
    HrmOrganization::Application::Commands::CreateRecord.new.call(actor: actor, resource: "organization_units", attributes: { code: code, name: name, unit_type: "branch", effective_from: from, effective_to: to, headcount_limit: 0 })
  end

  test "filters keep company scope and inclusive effective dates on web and API" do
    admin = make_user(:admin)
    other = make_user(:admin, company: Company.create!(code: "FILTER#{SecureRandom.hex(3).upcase}", name: "Other"))
    current = branch(admin, "NOW", name: "Hà Nội", from: Date.current, to: Date.current)
    future = branch(admin, "LATER", from: Date.tomorrow)
    ended = branch(admin, "OLD", from: Date.yesterday - 1, to: Date.yesterday)
    branch(other, "FOREIGN", name: "Hà Nội")
    headers = { "Authorization" => "Bearer #{ApiToken.issue!(admin)}" }
    get "/api/v1/organization/branches", params: { q: "Hà Nội", status: "current" }, headers: headers
    assert_response :success
    assert_equal 3, response.parsed_body["total"]
    assert_equal 1, response.parsed_body["matching"]
    assert_equal([ current.id ], response.parsed_body["records"].pluck("id"))
    { "upcoming" => future.id, "ended" => ended.id }.each do |status, id|
      get "/api/v1/organization/branches", params: { status: status }, headers: headers
      assert_response :success
      assert_equal([ id ], response.parsed_body["records"].map { |r| r["id"] })
    end
    post "/session", params: { email: admin.email, password: "StrongPassword123!" }
    get "/organization/branches", params: { q: "Hà Nội", status: "current" }
    assert_response :success
    assert_select "input[name=q][value='Hà Nội']"
    assert_select "a[href='/organization/organization-units/#{current.id}']"
    assert_not_includes response.body, "FOREIGN"
  end

  test "search treats wildcard and SQL text as literal and rejects structured input" do
    admin = make_user(:admin)
    exact = branch(admin, "LITERAL", name: "100%_! chi nhánh")
    branch(admin, "NORMAL", name: "100 percent")
    query = HrmOrganization::Application::Queries::Branches.new
    assert_equal [ exact.id ], query.call(actor: admin, q: "%_!")[:records].map(&:id)
    assert_empty query.call(actor: admin, q: "' OR 1=1 --")[:records]
    headers = { "Authorization" => "Bearer #{ApiToken.issue!(admin)}" }
    [ { q: [ "bad" ] }, { q: "a" * 101 }, { status: "unknown" }, { after: "-1" }, { after: "1 OR 1=1" } ].each do |params|
      get "/api/v1/organization/branches", params: params, headers: headers
      assert_response :unprocessable_entity
    end
    viewer = make_user(:employee)
    get "/api/v1/organization/branches", headers: { "Authorization" => "Bearer #{ApiToken.issue!(viewer)}" }
    assert_response :forbidden
    get "/api/v1/organization/branches"
    assert_response :unauthorized
  end

  test "cursor reaches branches beyond the old cap without duplicates and retains filters" do
    admin = make_user(:admin)
    101.times { |n| branch(admin, "PAGE#{n}", name: "Directory #{n}") }
    headers = { "Authorization" => "Bearer #{ApiToken.issue!(admin)}" }
    ids, cursor = [], nil
    5.times do
      params = { q: "Directory", status: "current" }
      params[:after] = cursor.to_s if cursor
      get "/api/v1/organization/branches", params: params, headers: headers
      assert_response :success
      body = response.parsed_body
      assert_equal 101, body["matching"]
      assert_operator body["records"].length, :<=, 25
      ids.concat(body["records"].map { |r| r["id"] })
      cursor = body["next_after"]
    end
    assert_nil cursor
    assert_equal 101, ids.uniq.length
    assert_equal ids.sort, ids
    post "/session", params: { email: admin.email, password: "StrongPassword123!" }
    get "/organization/branches", params: { q: "Directory", status: "current" }
    assert_response :success
    assert_select "a", text: "Trang tiếp →", count: 1
  end
end
