require "test_helper"
require "timeout"
require_relative "../support/procurement_fixtures"

class ConcurrentPurchaseRequestsTest < ActiveSupport::TestCase
  include ProcurementFixtures
  self.use_transactional_tests = false
  def setup
    @company = Company.create!(code: "BUYRACE#{SecureRandom.hex(4).upcase}", name: "Purchase race sample")
    @maker = make_user(:employee, company: @company)
    @reviewers = Array.new(2) { make_user(:manager, company: @company) }
    @record = submit_purchase(@maker, create_purchase(@maker))
    @threads = []
  end
  def teardown
    @threads.each { |thread| thread.kill if thread.alive? }
    # Privileged test cleanup: explicit history purge then parent FK cascade, never an app endpoint.
    PurchaseRequestEvent.where(company_id: @company.id).delete_all
    PurchaseRequest.where(company_id: @company.id).delete_all
    [ AuditLog, OutboxEvent ].each { |model| model.where(company_id: @company.id).delete_all }
    ids = User.where(company_id: @company.id).pluck(:id)
    [ UserPermission, LoginSession, ApiToken ].each { |model| model.where(user_id: ids).delete_all }
    User.where(id: ids).delete_all
    RolePermission.where(company_role_id: CompanyRole.where(company_id: @company.id).select(:id)).delete_all
    CompanyRole.where(company_id: @company.id).delete_all
    @company.reload.destroy!
    Current.reset
  end
  test "two reviewers produce one decision one history event and one outbox change" do
    ready, gate, results = Queue.new, Queue.new, Queue.new
    @record.with_lock do
      @threads = @reviewers.map do |actor|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            gate.pop
            begin
              decide_purchase(actor, @record, version: 1)
              results << :approved
            rescue StandardError => error
              results << error
            ensure
              Current.reset
            end
          end
        end
      end
      Timeout.timeout(10) { 2.times { ready.pop } }
      2.times { gate << true }
    end
    @threads.each { |thread| assert thread.join(20), "Decision lock timed out" }
    values = Array.new(2) { results.pop }
    assert_equal 1, values.count(:approved)
    assert_equal(1, values.count { |value| value.is_a?(ActiveRecord::StaleObjectError) })
    assert_equal "approved", @record.reload.status
    assert_equal 1, @record.events.where(action: "approved").count
    assert_equal 3, OutboxEvent.where(company_id: @company.id, event_type: %w[purchase_request.created purchase_request.updated]).count
  end
  test "revocation after an older caller snapshot is rejected by current locking grant reads" do
    ready, gate, result = Queue.new, Queue.new, Queue.new
    actor = @reviewers.first
    @threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        begin
          ActiveRecord::Base.transaction do
            assert actor.effective_permission_keys.include?("procurement.requests.review")
            ready << true
            gate.pop
            decide_purchase(actor, @record, version: 1)
          end
          result << :approved
        rescue StandardError => error
          result << error
        ensure
          Current.reset
        end
      end
    end
    Timeout.timeout(10) { ready.pop }
    UserPermission.create!(user: actor, permission: Permission.find_by!(key: "procurement.requests.review"), granted: false)
    gate << true
    assert @threads.first.join(20), "Grant lock timed out"
    assert_kind_of Pundit::NotAuthorizedError, result.pop
    assert_equal "submitted", @record.reload.status
    assert_equal 2, @record.events.count
  end
end
