require "test_helper"
require "action_cable/channel/test_case"
class CompanyChannelTest < ActionCable::Channel::TestCase
  tests HrUpdatesChannel
  test "staff stream is company scoped and ignores a client chosen company" do
    admin = make_user(:admin)
    stub_connection current_user: admin
    subscribe(company_id: admin.company_id + 100)
    assert subscription.confirmed?
    assert_has_stream "company_#{admin.company_id}_hr_updates"
    assert_equal 1, subscription.streams.size
    assert_not subscription.streams.include?("hr_updates")
  end
  test "a revoked realtime permission rejects subscription even for admin" do
    admin = make_user(:admin)
    admin.user_permissions.create!(permission: Permission.find_by!(key: "realtime.read"), granted: false)
    stub_connection current_user: admin
    subscribe
    assert subscription.rejected?
  end
end
