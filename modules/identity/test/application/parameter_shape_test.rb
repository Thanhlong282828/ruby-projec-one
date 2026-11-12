require "test_helper"

class ParameterShapeTest < ActionDispatch::IntegrationTest
  test "API company and branch forms reject scalar and array roots without writes" do
    actor = make_user(:admin)
    headers = { "Authorization" => "Bearer #{ApiToken.issue!(actor)}" }
    [ "bad-root", [ "bad-root" ] ].each do |invalid|
      assert_no_difference [ "Company.count", "OrganizationUnit.count" ] do
        post "/api/v1/system/companies", params: { company: invalid }, headers: headers, as: :json
        assert_response :bad_request
        post "/api/v1/organization/branches", params: { branch: invalid }, headers: headers, as: :json
        assert_response :bad_request
      end
    end
  end
end
