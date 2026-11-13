require "test_helper"
require "timeout"
require_relative "../support/return_fixtures"

class ConcurrentStockReturnsTest < ActiveSupport::TestCase
  include ReturnFixtures
  self.use_transactional_tests = false
  def setup
    @threads = []
    @company = Company.create!(code: "RTRACE#{SecureRandom.hex(4).upcase}", name: "Return concurrency sample")
    @buyer = make_user(:manager, company: @company)
    @maker = make_user(:employee, company: @company)
    order = receipt_order(@maker, @buyer)
    @warehouse = stock_catalog(@buyer, :warehouse)
    @item = stock_catalog(@buyer, :item)
    @entry = post_stock(@buyer, receive_order(@buyer, order), @warehouse, @item)
    @second = post_stock(@buyer, receive_order(@buyer, order, receiving_attributes(order, quantity: "6")), @warehouse, @item)
  end
  def teardown
    @threads.each { |thread| thread.kill if thread.alive? }
    # Only the isolated hrm_test database: TRUNCATE removes committed fixture documents
    # without adding a runtime deletion exception to the immutable ledger's guards.
    raise "Test cleanup must stay isolated" unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == "hrm_test"
    connection = ActiveRecord::Base.connection
    connection.disable_referential_integrity do
      connection.execute("TRUNCATE TABLE stock_return_lines")
      connection.execute("TRUNCATE TABLE stock_returns")
    end
    PurchaseOrderEvent.where(company_id: @company.id).delete_all
    PurchaseOrder.where(company_id: @company.id).delete_all
    StockItem.where(company_id: @company.id).delete_all
    Warehouse.where(company_id: @company.id).delete_all
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
    ready, go, results = Queue.new, Queue.new, Queue.new
    @threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          go.pop
          begin
            results << yield(User.find(@buyer.id))
          rescue StandardError => error
            results << error
          ensure
            Current.reset
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
  test "two simultaneous three-unit returns cannot consume more than the original four" do
    results = race { |actor| return_stock(actor, @entry) }
    assert_equal(1, results.count { |row| row.is_a?(StockReturn) })
    assert_equal(1, results.count { |row| row.is_a?(HrmProcurement::Domain::Services::RequestConflict) })
    assert_equal BigDecimal("3"), StockReturnLine.where(company_id: @company.id).sum(:quantity)
    assert_equal BigDecimal("7"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
  test "simultaneous same key and content returns one document and journals once" do
    attrs = return_attributes(@entry)
    results = race { |actor| return_stock(actor, @entry, attrs).id }
    assert results.all?(Integer), results.map(&:class).inspect
    assert_equal 1, results.uniq.size
    assert_equal 1, StockReturn.where(company_id: @company.id).count
    assert_equal 2, OutboxEvent.where(company_id: @company.id, event_type: %w[stock_return.created stock_return.updated]).count
    assert_equal BigDecimal("7"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
  test "same company key on two different sources gives a conflict rather than duplicate or SQL error" do
    sources = Queue.new
    sources << @entry << @second
    key = SecureRandom.uuid
    results = race do |actor|
      source = sources.pop
      return_stock(actor, source, return_attributes(source, key: key))
    end
    assert_equal(1, results.count { |row| row.is_a?(StockReturn) })
    assert_equal(1, results.count { |row| row.is_a?(HrmProcurement::Domain::Services::RequestConflict) })
    assert_equal 1, StockReturn.where(company_id: @company.id, idempotency_key: key).count
    assert_equal BigDecimal("7"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
  def stale_caller(&operation)
    ready, go, results = Queue.new, Queue.new, Queue.new
    @threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        begin
          ActiveRecord::Base.transaction do
            StockReturnLine.where(company_id: @company.id).load
            @buyer.effective_permission_keys
            ready << true
            go.pop
            results << yield
          end
        rescue StandardError => error
          results << error
        ensure
          Current.reset
        end
      end
    end
    Timeout.timeout(10) { ready.pop }
    yield_control = -> { go << true; raise "Return lock timeout" unless @threads.last.join(20); results.pop }
    yield_control
  end
  test "older caller snapshot reads newly committed returned quantities under source lock" do
    finish = stale_caller { return_stock(@buyer, @entry, return_attributes(@entry, quantity: "1")) }
    return_stock(@buyer, @entry, return_attributes(@entry, quantity: "4"))
    assert_kind_of HrmProcurement::Domain::Services::RequestConflict, finish.call
    assert_equal BigDecimal("4"), StockReturnLine.where(company_id: @company.id).sum(:quantity)
    assert_equal BigDecimal("6"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
  test "grant revoked after caller snapshot blocks return and replay" do
    finish = stale_caller { return_stock(@buyer, @entry) }
    UserPermission.create!(user: @buyer, permission: Permission.find_by!(key: "inventory.returns.post"), granted: false)
    assert_kind_of Pundit::NotAuthorizedError, finish.call
    assert_equal 0, StockReturn.where(company_id: @company.id).count
    assert_equal BigDecimal("10"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
  test "revoking read under an older caller snapshot also denies a read only replay" do
    attrs = return_attributes(@entry)
    record = return_stock(@buyer, @entry, attrs)
    finish = stale_caller { return_stock(@buyer, @entry, attrs) }
    UserPermission.create!(user: @buyer, permission: Permission.find_by!(key: "inventory.returns.read"), granted: false)
    assert_kind_of Pundit::NotAuthorizedError, finish.call
    assert_equal record.id, StockReturn.where(company_id: @company.id).sole.id
    assert_equal BigDecimal("7"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
end
