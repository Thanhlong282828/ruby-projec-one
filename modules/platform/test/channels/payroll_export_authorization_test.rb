require "test_helper"
class PayrollExportAuthorizationTest < ActiveSupport::TestCase
  test "realtime requires both source and export grants and revocation is live" do
    admin = make_user(:admin)
    message = { type: "payroll_export.created", id: 1 }
    assert Hrm::RealtimeAuthorization.allowed?(actor: admin, message: message)
    admin.user_permissions.create!(permission: Permission.find_by!(key: "payroll.read"), granted: false)
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: admin, message: message)
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: admin, message: { type: "payroll_export_access.created", id: 1 })
    hr = make_user(:hr)
    assert hr.allowed?("payroll.read")
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: hr, message: message)
    assert Hrm::RealtimeAuthorization.allowed?(actor: hr, message: { type: "employee.created", id: 1 })
  end
  test "malformed registry grants fail closed" do
    actor = make_user(:admin)
    old = Rails.application.config.x.hrm.realtime_permissions
    [ [], [ nil ], { bad: true }, false ].each do |value|
      Rails.application.config.x.hrm.realtime_permissions = { "payroll_export." => value }
      assert_not Hrm::RealtimeAuthorization.allowed?(actor: actor, message: { type: "payroll_export.created" })
    end
  ensure
    Rails.application.config.x.hrm.realtime_permissions = old
  end
end
