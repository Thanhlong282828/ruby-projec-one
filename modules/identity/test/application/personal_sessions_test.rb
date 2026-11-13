require "test_helper"
require "minitest/mock"

class PersonalSessionsTest < ActionDispatch::IntegrationTest
  def login(user)
    post "/session", params: { email: user.email, password: "StrongPassword123!" }
    assert_response :redirect
    LoginSession.where(principal_user_id: user.identity_id).order(:id).last
  end

  test "own sessions are projected without secrets and other identities cannot be enumerated or revoked" do
    actor = make_user(:employee)
    other = make_user(:admin)
    raw = LoginSession.issue!(actor)
    target = LoginSession.find_by!(digest: Digest::SHA256.hexdigest(raw))
    foreign_raw = LoginSession.issue!(other)
    foreign = LoginSession.find_by!(digest: Digest::SHA256.hexdigest(foreign_raw))
    current = login(actor)
    get "/my/sessions"
    assert_response :success
    assert_select "span.badge", text: "Phiên hiện tại"
    assert_select "form[action='/my/sessions/#{target.id}']"
    assert_select "form[action='/my/sessions/#{foreign.id}']", count: 0
    [ raw, target.digest, foreign_raw, foreign.digest ].each { |secret| assert_not_includes response.body, secret }
    assert_match(/no-store/, response.headers["Cache-Control"])
    delete "/my/sessions/#{foreign.id}"
    assert_response :not_found
    assert LoginSession.exists?(foreign.id)
    delete "/my/sessions/#{current.id}"
    assert_response :forbidden
    assert LoginSession.exists?(current.id)
    assert_difference -> { AuditLog.where(action: "security.web_session.revoked").count }, 1 do
      delete "/my/sessions/#{target.id}"
    end
    assert_response :redirect
    assert_not LoginSession.exists?(target.id)
    assert_nil HrmIdentity::Application::Queries::AuthenticateWebSession.new.call(raw: raw)
    get "/my/sessions"
    assert_response :success
  end

  test "identity owner may revoke own sessions in a different assigned company" do
    actor = make_user(:employee)
    company = Company.create!(code: "SESSION#{SecureRandom.hex(3).upcase}", name: "Assigned")
    profile = User.create!(company: company, principal_user: actor, email: actor.email, role: "employee")
    raw = LoginSession.issue!(profile)
    target = LoginSession.find_by!(digest: Digest::SHA256.hexdigest(raw))
    login(actor)
    get "/my/sessions"
    assert_response :success
    assert_includes response.body, "Assigned"
    delete "/my/sessions/#{target.id}"
    assert_response :redirect
    assert_not LoginSession.exists?(target.id)
    assert profile.reload.active?
  end

  test "expired revoked forged context and malformed cursors fail closed" do
    actor = make_user(:employee)
    current = login(actor)
    get "/my/sessions", params: { before: [ "1" ] }
    assert_response :not_found
    get "/my/sessions", params: { before: "1 OR 1=1" }
    assert_response :not_found
    current.update!(expires_at: 1.minute.ago)
    get "/my/sessions"
    assert_redirected_to "/session/new"
    assert_raises(Pundit::NotAuthorizedError) do
      HrmIdentity::Application::Queries::PersonalSessions.new.call(actor: actor, credential: current)
    end
    other = make_user(:admin)
    other_raw = LoginSession.issue!(other)
    foreign = LoginSession.find_by!(digest: Digest::SHA256.hexdigest(other_raw))
    assert_raises(Pundit::NotAuthorizedError) do
      HrmIdentity::Application::Commands::RevokePersonalSession.new.call(actor: actor, credential: foreign, id: foreign.id.to_s)
    end
  end

  test "revocation rolls back if audit fails and CSRF protects browser actions" do
    actor = make_user(:employee)
    raw = LoginSession.issue!(actor)
    target = LoginSession.find_by!(digest: Digest::SHA256.hexdigest(raw))
    current = login(actor)
    AuditLog.stub(:create!, ->(**_) { raise "audit unavailable" }) do
      assert_raises(RuntimeError) do
        HrmIdentity::Application::Commands::RevokePersonalSession.new.call(actor: actor, credential: current, id: target.id.to_s)
      end
    end
    assert LoginSession.exists?(target.id)
    old = ActionController::Base.allow_forgery_protection
    begin
      ActionController::Base.allow_forgery_protection = true
      delete "/my/sessions/#{target.id}"
      assert_response :unprocessable_entity
      assert LoginSession.exists?(target.id)
    ensure
      ActionController::Base.allow_forgery_protection = old
    end
  end
  test "cursor pagination never returns expired or foreign sessions and stale company context cannot revoke" do
    actor = make_user(:employee)
    28.times { LoginSession.issue!(actor) }
    expired = LoginSession.create!(user: actor, principal_user: actor, digest: SecureRandom.hex(32), expires_at: 1.minute.ago)
    current = login(actor)
    query = HrmIdentity::Application::Queries::PersonalSessions.new
    first = query.call(actor: actor, credential: current)
    assert_equal 25, first[:records].length
    second = query.call(actor: actor, credential: current, before: first[:next_before].to_s)
    ids = (first[:records] + second[:records]).pluck(:id)
    assert_equal 29, ids.uniq.length
    assert_not_includes ids, expired.id
    assert_nil second[:next_before]
    company = Company.create!(code: "CTX#{SecureRandom.hex(3).upcase}", name: "Context")
    profile = User.create!(company: company, principal_user: actor, email: actor.email, role: "employee")
    current.update!(user: profile)
    assert_raises(Pundit::NotAuthorizedError) do
      HrmIdentity::Application::Commands::RevokePersonalSession.new.call(actor: actor, credential: current, id: ids.last.to_s)
    end
    assert LoginSession.exists?(ids.last)
  end
  test "strict revoke keeps nil credential and malformed id rejection before mutation" do
    actor = make_user(:employee)
    current = login(actor)
    raw = LoginSession.issue!(actor)
    target = LoginSession.find_by!(digest: Digest::SHA256.hexdigest(raw))
    command = HrmIdentity::Application::Commands::RevokePersonalSession.new
    before_counts = [ AuditLog.count, OutboxEvent.count ]
    assert_raises(Pundit::NotAuthorizedError) { command.call(actor: nil, credential: current, id: target.id.to_s) }
    [ nil, "not a credential", {}, [] ].each do |credential|
      assert_raises(Pundit::NotAuthorizedError) { command.call(actor: actor, credential: credential, id: target.id.to_s) }
    end
    [ nil, target.id, [], {}, :bad, "0", "1 OR 1=1" ].each do |id|
      assert_raises(ActiveRecord::RecordNotFound) { command.call(actor: actor, credential: current, id: id) }
    end
    assert LoginSession.exists?(target.id)
    assert_equal before_counts, [ AuditLog.count, OutboxEvent.count ]
  end
end
