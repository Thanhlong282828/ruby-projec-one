require "test_helper"
class ConcurrentCompanyContextTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  def setup
    super
    @companies = Array.new(2) { Company.create!(code: "CTXRACE#{SecureRandom.hex(4).upcase}", name: "Context race") }
    @principal = make_user(:employee, company: @companies.first)
    @profile = User.create!(company: @companies.last, principal_user: @principal, email: @principal.email, role: "employee")
    @raw = ApiToken.issue!(@principal)
    @credential = HrmIdentity::Application::Queries::AuthenticateToken.new.call(raw: @raw)
  end

  def teardown
    @worker.kill if @worker&.alive?
    ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber
    ids = User.where(company_id: @companies.map(&:id)).pluck(:id)
    [ SystemAuditLog, AuditLog, OutboxEvent ].each { |model| model.where(company_id: @companies.map(&:id)).delete_all }
    [ ApiToken, LoginSession, UserPermission, SystemGrant ].each { |model| model.where(user_id: ids).delete_all }
    User.where(id: ids).where.not(principal_user_id: nil).delete_all
    User.where(id: ids).delete_all
    role_ids = CompanyRole.where(company_id: @companies.map(&:id)).pluck(:id)
    RolePermission.where(company_role_id: role_ids).delete_all
    CompanyRole.where(id: role_ids).delete_all
    @companies.each { |company| company.reload.destroy! }
    super
  end

  def start_waiter(lock_scope, &operation)
    @ready, @results = Queue.new, Queue.new
    observer = Object.new
    current = self
    observer.define_singleton_method(:start) do |_name, _id, payload|
      if Thread.current == current.instance_variable_get(:@worker) && payload[:sql].include?("FOR UPDATE") && payload[:sql].include?("users")
        if lock_scope == :principal || payload[:sql].include?("principal_user_id")
          current.instance_variable_get(:@ready) << true
        end
      end
    end
    observer.define_singleton_method(:finish) { |*| nil }
    @subscriber = ActiveSupport::Notifications.subscribe("sql.active_record", observer)
    @worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        begin
          ActiveRecord::Base.cache do
            if operation
              yield
            else
              HrmIdentity::Application::Commands::SwitchCompany.new.call(actor: @principal, credential: @credential, membership_id: @profile.id)
            end
          end
          @results << :switched
        rescue StandardError => error
          @results << error
        ensure
          Current.reset
        end
      end
    end
    Timeout.timeout(10) { @ready.pop }
  end

  test "disabled target membership while switch waits on its row lock cannot be entered" do
    @profile.with_lock do
      start_waiter(:profile)
      @profile.update!(active: false)
    end
    assert @worker.join(20), "Context lock timeout"
    assert_kind_of Pundit::NotAuthorizedError, @results.pop
    assert_equal @principal.id, @credential.reload.user_id
    assert_equal 0, AuditLog.where(company_id: @companies.last.id, action: "company.context.selected").count
  end

  test "principal password change while switch waits cannot resurrect its revoked credential" do
    @principal.with_lock do
      start_waiter(:principal)
      @principal.update!(password: "ReplacementPassword123!")
    end
    assert @worker.join(20), "Principal lock timeout"
    assert_kind_of ActiveRecord::RecordNotFound, @results.pop
    assert_nil HrmIdentity::Application::Queries::AuthenticateToken.new.call(raw: @raw)
    assert_equal 0, ApiToken.where(principal_user_id: @principal.id).count
  end
  test "a revoked caller waiting on principal lock cannot revoke another session" do
    first_raw = LoginSession.issue!(@principal)
    second_raw = LoginSession.issue!(@principal)
    current = LoginSession.find_by!(digest: Digest::SHA256.hexdigest(first_raw))
    target = LoginSession.find_by!(digest: Digest::SHA256.hexdigest(second_raw))
    @principal.with_lock do
      start_waiter(:principal) do
        HrmIdentity::Application::Commands::RevokePersonalSession.new.call(actor: @principal, credential: current, id: target.id.to_s)
      end
      current.destroy!
    end
    assert @worker.join(20), "Session revoke lock timeout"
    assert_kind_of Pundit::NotAuthorizedError, @results.pop
    assert LoginSession.exists?(target.id)
    assert_equal 0, AuditLog.where(company_id: @principal.company_id, action: "security.web_session.revoked").count
  end
end
