require "test_helper"
require "timeout"
require_relative "../support/stock_fixtures"

class ConcurrentStockReceiptsTest < ActiveSupport::TestCase
  include StockFixtures
  self.use_transactional_tests = false
  def setup
    @threads = []
    @company = Company.create!(code: "PORACE#{SecureRandom.hex(4).upcase}", name: "PO race sample")
    @maker = make_user(:employee, company: @company)
    @buyer = make_user(:manager, company: @company)
    @source = approved_source(@maker, @buyer)
    @supplier = supplier_for(@buyer)
    @threads = []
    @order = receipt_order(@maker, @buyer)
    @receipt = receive_order(@buyer, @order)
    @warehouse = stock_catalog(@buyer, :warehouse)
    @item = stock_catalog(@buyer, :item)
  end
  def teardown
    @threads.each { |thread| thread.kill if thread.alive? }
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
  test "simultaneous posting of one source creates one entry and increases stock once" do
    results = race { |actor| post_stock(actor, @receipt, @warehouse, @item).id }
    assert results.all?(Integer), results.map { |value| value.class.name }.inspect
    assert_equal 1, results.uniq.size
    assert_equal 1, StockReceipt.where(company_id: @company.id).count
    assert_equal BigDecimal("4"), balances(@buyer)[:records].first[:quantity]
  end
  test "simultaneous conflicting mapping records exactly one destination" do
    alternate = stock_catalog(@buyer, :warehouse, code: "ALT")
    choices = Queue.new
    choices << @warehouse << alternate
    results = race { |actor| post_stock(actor, @receipt, choices.pop, @item) }
    assert_equal(1, results.count { |value| value.is_a?(StockReceipt) })
    assert_equal(1, results.count { |value| value.is_a?(HrmProcurement::Domain::Services::RequestConflict) })
    assert_equal BigDecimal("4"), StockMovement.where(company_id: @company.id).sum(:quantity)
  end
  test "older source snapshot after another posting still replays only once" do
    ready, go, result = Queue.new, Queue.new, Queue.new
    @threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        begin
          ActiveRecord::Base.transaction do
            raise "Unexpected fixture entry" if StockReceipt.exists?(goods_receipt_id: @receipt.id)
            ready << true
            go.pop
            result << post_stock(User.find(@buyer.id), @receipt, @warehouse, @item).id
          end
        rescue StandardError => error
          result << error
        ensure
          Current.reset
        end
      end
    end
    Timeout.timeout(10) { ready.pop }
    original = post_stock(@buyer, @receipt, @warehouse, @item)
    go << true
    assert @threads.first.join(20), "Posting lock timed out"
    assert_equal original.id, result.pop
    assert_equal BigDecimal("4"), StockMovement.where(company_id: @company.id).sum(:quantity)
  end
  test "current grant revocation wins over an old caller snapshot" do
    ready, go, result = Queue.new, Queue.new, Queue.new
    @threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        begin
          ActiveRecord::Base.transaction do
            raise "Missing fixture grant" unless @buyer.effective_permission_keys.include?("inventory.receipts.post")
            ready << true
            go.pop
            post_stock(@buyer, @receipt, @warehouse, @item)
          end
          result << :posted
        rescue StandardError => error
          result << error
        ensure
          Current.reset
        end
      end
    end
    Timeout.timeout(10) { ready.pop }
    UserPermission.create!(user: @buyer, permission: Permission.find_by!(key: "inventory.receipts.post"), granted: false)
    go << true
    assert @threads.first.join(20), "Permission lock timed out"
    assert_kind_of Pundit::NotAuthorizedError, result.pop
    assert_equal 0, StockReceipt.where(company_id: @company.id).count
    assert_empty balances(@buyer)[:records]
  end
end
