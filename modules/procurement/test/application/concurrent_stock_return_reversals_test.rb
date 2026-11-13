require "test_helper"
require "timeout"
require_relative "../support/reversal_fixtures"

class ConcurrentStockReturnReversalsTest < ActiveSupport::TestCase
  include ReversalFixtures
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
    @source = return_stock(@buyer, @entry)
    @second = post_stock(@buyer, receive_order(@buyer, order, receiving_attributes(order, quantity: "6")), @warehouse, @item)
  end
  def teardown
    @threads.each { |thread| thread.kill if thread.alive? }
    # Only the isolated hrm_test database: TRUNCATE removes committed fixture documents
    # without adding a runtime deletion exception to the immutable ledger's guards.
    raise "Test cleanup must stay isolated" unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == "hrm_test"
    connection = ActiveRecord::Base.connection
    connection.disable_referential_integrity do
      connection.execute("TRUNCATE TABLE stock_return_reversal_lines")
      connection.execute("TRUNCATE TABLE stock_return_reversals")
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
  test "simultaneous full reversals with distinct keys post only once" do
    results = race { |actor| reverse_stock(actor, @source) }
    assert_equal(1, results.count { |row| row.is_a?(StockReturnReversal) })
    assert_equal(1, results.count { |row| row.is_a?(HrmProcurement::Domain::Services::RequestConflict) })
    assert_equal 1, StockReturnReversal.where(company_id: @company.id).count
    assert_equal BigDecimal("10"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
  test "same key replay on two connections journals just once" do
    attrs = reversal_attributes
    results = race { |actor| reverse_stock(actor, @source, attrs).id }
    assert results.all?(Integer), results.map(&:class).inspect
    assert_equal 1, results.uniq.size
    assert_equal 2, OutboxEvent.where(company_id: @company.id, event_type: %w[stock_return_reversal.created stock_return_reversal.updated]).count
  end
  test "same key on different sources conflicts rather than reversing both" do
    other = return_stock(@buyer, @second)
    sources = Queue.new
    sources << @source << other
    key = SecureRandom.uuid
    results = race { |actor| reverse_stock(actor, sources.pop, reversal_attributes(key: key)) }
    assert_equal(1, results.count { |row| row.is_a?(StockReturnReversal) })
    assert_equal(1, results.count { |row| row.is_a?(HrmProcurement::Domain::Services::RequestConflict) })
    assert_equal 1, StockReturnReversal.where(company_id: @company.id).count
  end
  test "new return and reversal share the source lock without over returning or losing restoration" do
    actions = Queue.new
    actions << :return << :reverse
    results = race do |actor|
      actions.pop == :return ? return_stock(actor, @entry, return_attributes(@entry, quantity: "3")) : reverse_stock(actor, @source)
    end
    assert_equal(1, results.count { |row| row.is_a?(StockReturnReversal) })
    assert results.all? { |row| row.is_a?(StockReturn) || row.is_a?(StockReturnReversal) || row.is_a?(HrmProcurement::Domain::Services::RequestConflict) }, results.map(&:class).inspect
    returned = results.any?(StockReturn)
    assert_equal BigDecimal(returned ? "7" : "10"), balances(@buyer, @warehouse)[:records].first[:quantity]
    assert_equal BigDecimal(returned ? "1" : "4"), return_source(@buyer, @entry)[:lines].first[:remaining]
  end
  def stale_caller(&operation)
    ready, go, results = Queue.new, Queue.new, Queue.new
    @threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        begin
          ActiveRecord::Base.transaction do
            StockReturnReversalLine.where(company_id: @company.id).load
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
  test "older return writer snapshot sees a committed reversal and restored entitlement" do
    finish = stale_caller { return_stock(@buyer, @entry, return_attributes(@entry, quantity: "4")) }
    reverse_stock(@buyer, @source)
    assert_kind_of StockReturn, finish.call
    assert_equal BigDecimal("6"), balances(@buyer, @warehouse)[:records].first[:quantity]
    assert_equal BigDecimal("0"), return_source(@buyer, @entry)[:lines].first[:remaining]
  end
  test "reversal grant revoked after old snapshot blocks writing" do
    finish = stale_caller { reverse_stock(@buyer, @source) }
    UserPermission.create!(user: @buyer, permission: Permission.find_by!(key: "inventory.return_reversals.post"), granted: false)
    assert_kind_of Pundit::NotAuthorizedError, finish.call
    assert_equal 0, StockReturnReversal.where(company_id: @company.id).count
    assert_equal BigDecimal("7"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
  test "revoked read blocks replay even from an older snapshot" do
    attrs = reversal_attributes
    record = reverse_stock(@buyer, @source, attrs)
    finish = stale_caller { reverse_stock(@buyer, @source, attrs) }
    UserPermission.create!(user: @buyer, permission: Permission.find_by!(key: "inventory.return_reversals.read"), granted: false)
    assert_kind_of Pundit::NotAuthorizedError, finish.call
    assert_equal record.id, StockReturnReversal.where(company_id: @company.id).sole.id
  end
end
