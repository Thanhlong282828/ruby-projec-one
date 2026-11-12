require "test_helper"
require "minitest/mock"
class MultiCompanyTest < ActionDispatch::IntegrationTest
  def setup
    super
    @owner = make_user(:admin)
    @write = Hrm::Container.resolve(HrmIdentity::Domain::Repositories::TenantWriteRepositoryInterface)
    @read = Hrm::Container.resolve(HrmIdentity::Domain::Repositories::TenantReadRepositoryInterface)
    @write.grant_system_owner!(email: @owner.email)
  end
  def create_company(code: "CO#{SecureRandom.hex(4).upcase}")
    @write.create_company!(actor: @owner, attributes: { code: code, name: "Independent company" })
  end
  def profile(company, user = @owner) = User.find_by!(company: company, principal_user_id: user.identity_id)
  def web_login(user = @owner)
    post "/session", params: { email: user.email, password: "StrongPassword123!" }
  end
  test "installation owner rights are distinct from company roles and overrides" do
    admin = make_user(:admin)
    assert_not admin.allowed?("system.companies.read")
    admin.user_permissions.create!(permission: Permission.find_by!(key: "system.companies.read"), granted: true)
    assert_not admin.allowed?("system.companies.read")
    assert_raises(Pundit::NotAuthorizedError) { @read.companies(actor: admin) }
    assert @owner.allowed?("system.companies.manage")
    SystemGrant.where(user_id: @owner.id).delete_all
    assert_not @owner.allowed?("system.companies.manage")
    assert_raises(Pundit::NotAuthorizedError) { create_company }
  end
  test "company creation provisions an actual passwordless membership and separate MySQL roles atomically" do
    company = nil
    assert_difference [ "Company.count", "User.count" ], 1 do
      assert_difference [ "SystemAuditLog.count", "OutboxEvent.count" ], 2 do
        company = create_company
      end
    end
    membership = profile(company)
    assert_nil membership.password_digest
    assert_equal @owner.id, membership.principal_user_id
    assert_equal @owner.email, membership.email
    assert_equal "admin", membership.role
    assert membership.allowed?("employees.create")
    assert_not_equal @owner.company.company_roles.find_by!(key: "admin").id, company.company_roles.find_by!(key: "admin").id
    assert_equal 1, User.where(principal_user_id: nil, email: @owner.email).count
    assert_equal 2, @read.memberships(actor: @owner).size
  end
  test "same principal can have different roles and deny overrides in different companies" do
    company = create_company
    principal = make_user(:employee)
    membership = @write.assign_membership!(actor: @owner, company_id: company.id, principal_id: principal.id, role: "hr")
    assert membership.allowed?("employees.create")
    assert_not principal.allowed?("employees.create")
    membership.user_permissions.create!(permission: Permission.find_by!(key: "employees.create"), granted: false)
    assert_not membership.allowed?("employees.create")
    assert_not principal.allowed?("employees.create")
    assert_no_difference "User.count" do
      assert_equal membership.id, @write.assign_membership!(actor: @owner, company_id: company.id, principal_id: principal.id, role: "hr").id
    end
  end
  test "web switch uses assigned membership and company scoped sources options exports cache and writes follow context" do
    company = create_company
    membership = profile(company)
    Department.create!(company: @owner.company, code: "HOME", name: "HOME_PRIVATE_DEPARTMENT")
    Department.create!(company: company, code: "TARGET", name: "TARGET_PRIVATE_DEPARTMENT")
    web_login
    get "/departments"
    assert_includes response.body, "HOME_PRIVATE_DEPARTMENT"
    post "/my/company-context", params: { membership_id: membership.id, company_id: 999999, role: "root" }
    assert_response :redirect
    get "/departments"
    assert_response :success
    assert_includes response.body, "TARGET_PRIVATE_DEPARTMENT"
    assert_not_includes response.body, "HOME_PRIVATE_DEPARTMENT"
    post "/my/company-context", params: { membership_id: @owner.id }
    get "/departments"
    assert_includes response.body, "HOME_PRIVATE_DEPARTMENT"
    assert_not_includes response.body, "TARGET_PRIVATE_DEPARTMENT"
  end
  test "API context uses same opaque credential with absolute expiry and cannot choose unassigned membership" do
    company = create_company
    membership = profile(company)
    raw = ApiToken.issue!(@owner)
    token = HrmIdentity::Application::Queries::AuthenticateToken.new.call(raw: raw)
    expiry = token.expires_at
    headers = { "Authorization" => "Bearer #{raw}" }
    get "/api/v1/my/companies", headers: headers
    assert_response :success
    assert_equal 2, response.parsed_body.size
    post "/api/v1/my/company-context", params: { membership_id: membership.id }, headers: headers, as: :json
    assert_response :success
    assert_equal company.id, response.parsed_body["company_id"]
    assert_equal membership.id, HrmIdentity::Application::Queries::AuthenticateToken.new.call(raw: raw).user_id
    assert_equal expiry, token.reload.expires_at
    foreign = make_user(:admin)
    post "/api/v1/my/company-context", params: { membership_id: foreign.id }, headers: headers, as: :json
    assert_response :not_found
    assert_equal membership.id, token.reload.user_id
    token.update!(expires_at: 1.second.ago)
    post "/api/v1/my/company-context", params: { membership_id: @owner.id }, headers: headers, as: :json
    assert_response :unauthorized
  end
  test "principal password change revokes all company credentials while profile disable is local" do
    membership = profile(create_company)
    home = ApiToken.issue!(@owner)
    other = ApiToken.issue!(membership)
    login = LoginSession.issue!(membership)
    membership.update!(active: false)
    assert_nil HrmIdentity::Application::Queries::AuthenticateToken.new.call(raw: other)
    assert_nil HrmIdentity::Application::Queries::AuthenticateWebSession.new.call(raw: login)
    assert HrmIdentity::Application::Queries::AuthenticateToken.new.call(raw: home)
    membership.update!(active: true)
    other = ApiToken.issue!(membership)
    @owner.update!(password: "AnotherStrongPassword123!")
    assert_nil HrmIdentity::Application::Queries::AuthenticateToken.new.call(raw: home)
    assert_nil HrmIdentity::Application::Queries::AuthenticateToken.new.call(raw: other)
  end
  test "forged principal bindings chains credentials and membership password fail closed" do
    membership = profile(create_company)
    foreign = make_user(:admin)
    raw = ApiToken.issue!(membership)
    token = HrmIdentity::Application::Queries::AuthenticateToken.new.call(raw: raw)
    token.update_columns(principal_user_id: foreign.id) # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    assert_nil HrmIdentity::Application::Queries::AuthenticateToken.new.call(raw: raw)
    assert_raises(ActiveRecord::RecordInvalid) { membership.update!(password: "AnotherStrongPassword123!") }
    assert_raises(ActiveRecord::RecordInvalid) { User.create!(company: foreign.company, principal_user: membership, email: membership.email, role: "employee") }
    assert_raises(ActiveRecord::StatementInvalid) { User.where(id: membership.id).update_all(password_digest: @owner.password_digest) } # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
  end
  test "company is disabled independently and login can use another active membership" do
    membership = profile(create_company)
    @owner.company.update!(active: false)
    user = HrmIdentity::Application::Queries::AuthenticateUser.new.call(email: @owner.email, password: "StrongPassword123!")
    assert_equal membership.id, user.id
    membership.company.update!(active: false)
    assert_nil HrmIdentity::Application::Queries::AuthenticateUser.new.call(email: @owner.email, password: "StrongPassword123!")
  end
  test "switch is CSRF protected requires Bearer for API and cannot extend or switch a revoked session" do
    company = create_company
    membership = profile(company)
    web_login
    get "/api/v1/my/companies"
    assert_response :unauthorized
    old = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    post "/my/company-context", params: { membership_id: membership.id }
    assert_response :unprocessable_entity
    ActionController::Base.allow_forgery_protection = old
    raw = LoginSession.issue!(@owner)
    credential = HrmIdentity::Application::Queries::AuthenticateWebSession.new.call(raw: raw)
    expiry = credential.expires_at
    @write.switch!(actor: @owner, credential: credential, membership_id: membership.id)
    assert_equal expiry, credential.reload.expires_at
    assert_equal membership.id, HrmIdentity::Application::Queries::AuthenticateWebSession.new.call(raw: raw).user_id
    credential.destroy!
    assert_raises(ActiveRecord::RecordNotFound) { @write.switch!(actor: membership, credential: credential, membership_id: @owner.id) }
  ensure
    ActionController::Base.allow_forgery_protection = old
  end
  test "typed inputs stale writes recovery and root UI branch ownership are guarded" do
    company = create_company
    assert_raises(HrmIdentity::Domain::Services::TenantInput::Invalid) { @read.companies(actor: @owner, before: {}) }
    assert_raises(ActiveRecord::StaleObjectError) { @write.update_company!(actor: @owner, id: company.id, attributes: { name: "Changed", active: true }, lock_version: 99) }
    assert_raises(HrmIdentity::Domain::Services::TenantInput::Invalid) { @write.update_company!(actor: @owner, id: @owner.company_id, attributes: { name: "Home", active: false }, lock_version: @owner.company.lock_version) }
    web_login
    get "/system/companies"
    assert_response :success
    assert_select "a[href='/system/companies/#{company.id}']"
    get "/system/companies/#{company.id}"
    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_not_includes response.body, @owner.password_digest
  end
  test "company membership and context audit roll back when outbox fails" do
    original = Hrm::Container.method(:resolve)
    broken = Object.new
    def broken.append!(**) = raise(IOError, "outbox unavailable")
    resolver = ->(contract) { contract == HrmPlatform::Domain::Repositories::OutboxRepositoryInterface ? broken : original.call(contract) }
    assert_no_difference [ "Company.count", "User.count", "SystemAuditLog.count", "OutboxEvent.count" ] do
      Hrm::Container.stub(:resolve, resolver) { assert_raises(IOError) { create_company } }
    end
  end
  test "MySQL triggers reject self references chains and identity moves even through raw SQL" do
    company = create_company
    membership = profile(company)
    sql = User.connection
    assert_raises(ActiveRecord::StatementInvalid) do
      sql.execute("UPDATE users SET principal_user_id=id, password_digest=NULL WHERE id=#{@owner.id}")
    end
    assert_nil @owner.reload.principal_user_id
    assert @owner.authenticate("StrongPassword123!")
    assert_raises(ActiveRecord::StatementInvalid) do
      sql.execute("UPDATE users SET company_id=#{company.id} WHERE id=#{@owner.id}")
    end
    next_id = sql.select_value("SELECT AUTO_INCREMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users'").to_i
    email = sql.quote("self-#{SecureRandom.hex(4)}@example.test")
    now = sql.quote(Time.current)
    assert_no_difference "User.count" do
      assert_raises(ActiveRecord::StatementInvalid) do
        sql.execute("INSERT INTO users (id,company_id,principal_user_id,email,role,password_digest,active,created_at,updated_at) VALUES (#{next_id},#{company.id},#{next_id},#{email},'employee',NULL,1,#{now},#{now})")
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      sql.execute("INSERT INTO users (company_id,principal_user_id,email,role,password_digest,active,created_at,updated_at) VALUES (#{@owner.company_id},#{membership.id},#{email},'employee',NULL,1,#{now},#{now})")
    end
    names = sql.select_values("SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE() AND EVENT_OBJECT_TABLE='users'")
    assert_includes names, "users_membership_insert_guard"
    assert_includes names, "users_membership_update_guard"
  end

  test "company account administration cannot disable an installation owner" do
    assert_raises(ActiveRecord::RecordInvalid) { @owner.update!(active: false) }
    assert @owner.reload.active?
  end

  test "existing Action Cable identity cannot keep the old company after session switch" do
    membership = profile(create_company)
    raw = LoginSession.issue!(@owner)
    credential = HrmIdentity::Application::Queries::AuthenticateWebSession.new.call(raw: raw)
    cable = ApplicationCable::Connection.allocate
    cable.define_singleton_method(:current_user) { @actor }
    cable.instance_variable_set(:@actor, @owner)
    cable.define_singleton_method(:authenticated_session) { HrmIdentity::Application::Queries::AuthenticateWebSession.new.call(raw: raw) }
    assert cable.session_authenticated?
    @write.switch!(actor: @owner, credential: credential, membership_id: membership.id)
    assert_not cable.session_authenticated?
  end
end
