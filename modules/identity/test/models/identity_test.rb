require "test_helper"
class IdentityDomainTest < ActiveSupport::TestCase
  test "expired token is excluded and raw token never persisted" do
    user = make_user
    raw = ApiToken.issue!(user)
    assert_nil ApiToken.find_by(digest: raw)
    token = user.api_tokens.last
    token.update!(expires_at: 1.minute.ago)
    assert_not ApiToken.valid_now.exists?(token.id)
  end
end
