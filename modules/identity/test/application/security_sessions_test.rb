require "test_helper"
class SecuritySessionsTest < ActiveSupport::TestCase
  def setup
    super
    @user = make_user
    @open = HrmIdentity::Application::Commands::OpenWebSession.new
    @read = HrmIdentity::Application::Queries::AuthenticateWebSession.new
    @close = HrmIdentity::Application::Commands::CloseWebSession.new
  end
  test "session persists only digest and has an absolute eight hour lifetime" do
    raw = @open.call(actor: @user)
    row = @user.login_sessions.last
    assert_equal Digest::SHA256.hexdigest(raw), row.digest
    assert_not_equal raw, row.digest
    assert_equal @user.id, @read.call(raw: raw).user_id
    travel 8.hours + 1.second do
      assert_nil @read.call(raw: raw)
    end
  end
  test "logout revocation cannot be replayed and does not revoke other sessions" do
    first = @open.call(actor: @user)
    second = @open.call(actor: @user)
    @close.call(raw: first)
    assert_nil @read.call(raw: first)
    assert @read.call(raw: second)
    assert_nothing_raised { @close.call(raw: first) }
  end
  test "password change revokes all web and API credentials atomically" do
    raw = @open.call(actor: @user)
    token = HrmIdentity::Application::Commands::IssueToken.new.call(actor: @user)
    @user.update!(password: "OtherStrongPassword123!")
    assert_nil @read.call(raw: raw)
    assert_nil HrmIdentity::Application::Queries::AuthenticateToken.new.call(raw: token)
    assert_equal 0, @user.login_sessions.count
    assert_equal 0, @user.api_tokens.count
  end
  test "rollback of password change retains credentials" do
    raw = @open.call(actor: @user)
    @user.transaction do
      @user.update!(password: "OtherStrongPassword123!")
      raise ActiveRecord::Rollback
    end
    assert @read.call(raw: raw)
  end
  test "disabled and reactivated account cannot reuse old credentials" do
    raw = @open.call(actor: @user)
    @user.update!(active: false)
    @user.update!(active: true)
    assert_nil @read.call(raw: raw)
  end
  test "disabled company prevents authenticating an existing session" do
    raw = @open.call(actor: @user)
    @user.company.update!(active: false)
    assert_nil @read.call(raw: raw)
  end
  test "stale password actor cannot issue new web or API credential" do
    stale = User.find(@user.id)
    @user.update!(password: "OtherStrongPassword123!")
    assert_raises(Pundit::NotAuthorizedError) { @open.call(actor: stale) }
    stale = User.find(@user.id)
    @user.update!(password: "AnotherStrongPassword123!")
    assert_raises(Pundit::NotAuthorizedError) { HrmIdentity::Application::Commands::IssueToken.new.call(actor: stale) }
  end
  test "malformed credentials are rejected without repository calls" do
    [ nil, [], {}, "x", "' OR 1=1", "x" * 1000 ].each do |raw|
      assert_nil @read.call(raw: raw)
    end
    auth = HrmIdentity::Application::Queries::AuthenticateUser.new
    assert_nil auth.call(email: [], password: "x")
    assert_nil auth.call(email: @user.email, password: {})
    assert_nil auth.call(email: @user.email, password: "a" * 73)
  end
  test "unknown account follows bcrypt comparison path and returns nil" do
    assert BCrypt::Password.valid_hash?(HrmIdentity::Application::Queries::AuthenticateUser.dummy_digest)
    assert_nil HrmIdentity::Application::Queries::AuthenticateUser.new.call(email: "nobody@example.test", password: "WrongPassword123!")
  end
  test "credential cleanup removes only expired records and keeps valid sessions" do
    expired = @open.call(actor: @user)
    token = HrmIdentity::Application::Commands::IssueToken.new.call(actor: @user)
    @user.login_sessions.last.update!(expires_at: 1.second.ago)
    @user.api_tokens.last.update!(expires_at: 1.second.ago)
    valid = @open.call(actor: @user)
    assert_equal 2, PurgeCredentialsJob.perform_now
    assert_nil @read.call(raw: expired)
    assert_nil HrmIdentity::Application::Queries::AuthenticateToken.new.call(raw: token)
    assert @read.call(raw: valid)
  end
end
