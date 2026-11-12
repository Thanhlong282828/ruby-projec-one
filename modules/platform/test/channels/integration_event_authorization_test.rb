require "test_helper"
class IntegrationEventAuthorizationTest < ActiveSupport::TestCase
  test "HR realtime alone cannot receive Integration metadata" do
    hr = make_user(:hr)
    assert Hrm::RealtimeAuthorization.allowed?(actor: hr, message: { type: "employee.created", id: 1 })
    %w[integration_webhook.created integration_delivery.created integration_delivery_attempt.created].each do |type|
      assert_not Hrm::RealtimeAuthorization.allowed?(actor: hr, message: { type: type, id: 1 })
    end
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: hr, message: { "type" => "integration_connection.updated", "id" => 1 })
  end
  test "revoked Integration permission applies to existing realtime actors" do
    admin = make_user(:admin)
    message = { type: "integration_webhook.created", id: 1 }
    assert Hrm::RealtimeAuthorization.allowed?(actor: admin, message: message)
    admin.user_permissions.create!(permission: Permission.find_by!(key: "integration.read"), granted: false)
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: admin, message: message)
    assert Hrm::RealtimeAuthorization.allowed?(actor: admin, message: { type: "employee.created", id: 1 })
  end
  test "realtime permission is required even when Integration read remains" do
    admin = make_user(:admin)
    admin.user_permissions.create!(permission: Permission.find_by!(key: "realtime.read"), granted: false)
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: admin, message: { type: "integration_connection.created" })
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: nil, message: { type: "integration_connection.created" })
  end
  test "malformed realtime payloads are dropped" do
    admin = make_user(:admin)
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: admin, message: "not an event")
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: admin, message: { type: { malformed: true } })
  end
end
