require "test_helper"
class IdentityUseCasesTest < ActiveSupport::TestCase
  test "revocation command rejects another user's token" do
    user = make_user
    other = make_user
    ApiToken.issue!(other)
    token = other.api_tokens.last
    assert_raises(Pundit::NotAuthorizedError) do
      HrmIdentity::Application::Commands::RevokeToken.new.call(actor: user, token: token)
    end
    assert token.reload.persisted?
  end
end
