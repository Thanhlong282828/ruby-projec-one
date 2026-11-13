require "test_helper"
require "timeout"
require_relative "../support/order_fixtures"

class ConcurrentPurchaseOrdersTest < ActiveSupport::TestCase
  include OrderFixtures
  self.use_transactional_tests = false
  def setup
    @company = Company.create!(code: "PORACE#{SecureRandom.hex(4).upcase}", name: "PO race sample")
    @maker = make_user(:employee, company: @company)
    @buyer = make_user(:manager, company: @company)
    @source = approved_source(@maker, @buyer)
    @supplier = supplier_for(@buyer)
    @threads = []
  end
  def teardown
    @threads.each { |thread| thread.kill if thread.alive? }
    PurchaseOrderEvent.where(company_id: @company.id).delete_all
    PurchaseOrder.where(company_id: @company.id).delete_all
    ProcurementSupplier.where(company_id: @company.id).delete_all
    PurchaseRequestEvent.where(company_id: @company.id).delete_all
    PurchaseRequest.where(company_id: @company.id).delete_all
    [ AuditLog, OutboxEvent ].each { |model| model.where(company_id: @company.id).delete_all }
    users = User.where(company_id: @company.id)
    [ UserPermission, LoginSession, ApiToken ].each { |model| model.where(user_id: users.select(:id)).delete_all }
    users.delete_all
    RolePermission.where(company_role_id: CompanyRole.where(company_id: @company.id).select(:id)).delete_all
    CompanyRole.where(company_id: @company.id).delete_all
    @company.reload.destroy!
  end
  def race
    ready = Queue.new
    go = Queue.new
    results = Queue.new
    @threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          begin
            results << yield(User.find(@buyer.id))
          rescue StandardError => error
            results << error
          end
        end
      end
    end
    Timeout.timeout(20) do
      2.times { ready.pop }
      2.times { go << true }
      @threads.each(&:join)
    end
    Array.new(2) { results.pop }
  end
  test "two simultaneous creates return one PO with one source and history" do
    results = race { |actor| create_order(actor, @source, @supplier).id }
    assert results.all?(Integer), results.map { |value| value.class.name }.inspect
    assert_equal 1, results.uniq.size
    assert_equal 1, PurchaseOrder.where(company_id: @company.id).count
    assert_equal 1, PurchaseOrderEvent.where(company_id: @company.id).count
  end
  test "two simultaneous issues produce exactly one immutable issue event" do
    record = create_order(@buyer, @source, @supplier)
    results = race { |actor| issue_order(actor, record, version: 0) }
    assert_equal(1, results.count { |value| value.is_a?(PurchaseOrder) })
    assert_equal(1, results.count { |value| value.is_a?(ActiveRecord::StaleObjectError) })
    assert_equal "issued", record.reload.status
    assert_equal 1, record.events.where(action: "issued").count
  end
  test "revoked issue grant after an older caller snapshot cannot issue PO" do
    record = create_order(@buyer, @source, @supplier)
    ready, go, result = Queue.new, Queue.new, Queue.new
    @threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        begin
          ActiveRecord::Base.transaction do
            raise "Missing fixture grant" unless @buyer.effective_permission_keys.include?("procurement.orders.issue")
            ready << true
            go.pop
            issue_order(@buyer, record, version: 0)
          end
          result << :issued
        rescue StandardError => error
          result << error
        ensure
          Current.reset
        end
      end
    end
    Timeout.timeout(10) { ready.pop }
    UserPermission.create!(user: @buyer, permission: Permission.find_by!(key: "procurement.orders.issue"), granted: false)
    go << true
    assert @threads.first.join(20), "Grant lock timed out"
    assert_kind_of Pundit::NotAuthorizedError, result.pop
    assert_equal "draft", record.reload.status
    assert_equal 1, record.events.count
  end
end
