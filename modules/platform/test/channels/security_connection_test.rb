require "test_helper"
require "action_cable/connection/test_case"
class SecurityConnectionTest < ActionCable::Connection::TestCase
  tests ApplicationCable::Connection
  test "opaque unexpired login session authenticates cable and logout revokes existing connection" do
    user = make_user(:admin)
    raw = HrmIdentity::Application::Commands::OpenWebSession.new.call(actor: user)
    connect session: { login_token: raw }
    assert_equal user.id, connection.current_user.id
    assert connection.session_authenticated?
    HrmIdentity::Application::Commands::CloseWebSession.new.call(raw: raw)
    assert_not connection.session_authenticated?
  end
  test "legacy user id alone cannot authenticate cable" do
    assert_reject_connection { connect session: { user_id: make_user(:admin).id } }
  end
end
