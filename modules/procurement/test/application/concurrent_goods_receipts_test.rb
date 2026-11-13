require "test_helper"
require "timeout"
require_relative "../support/receipt_fixtures"

class ConcurrentGoodsReceiptsTest < ActiveSupport::TestCase
  include ReceiptFixtures
  self.use_transactional_tests = false
  def setup
    @company = Company.create!(code: "PORACE#{SecureRandom.hex(4).upcase}", name: "PO race sample")
    @maker = make_user(:employee, company: @company)
    @buyer = make_user(:manager, company: @company)
    @source = approved_source(@maker, @buyer)
    @supplier = supplier_for(@buyer)
    @threads = []
    @order = receipt_order(@maker, @buyer)
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
  test "two receivers cannot both consume the remaining quantity" do
    receive_order(@buyer, @order)
    results = race { |actor| receive_order(actor, @order, receiving_attributes(@order, quantity: "6")) }
    assert_equal(1, results.count { |value| value.is_a?(GoodsReceipt) })
    assert_equal(1, results.count { |value| value.is_a?(HrmProcurement::Domain::Services::RequestConflict) })
    assert_equal BigDecimal("10"), GoodsReceiptLine.where(purchase_order_id: @order.id).sum(:quantity)
    assert_equal 2, GoodsReceipt.where(purchase_order_id: @order.id, status: "recorded").count
  end
  test "simultaneous identical idempotency keys return one durable receipt" do
    input = receiving_attributes(@order, quantity: "10")
    results = race { |actor| receive_order(actor, @order, input).id }
    assert results.all?(Integer), results.map { |value| value.class.name }.inspect
    assert_equal 1, results.uniq.size
    assert_equal 1, GoodsReceipt.where(purchase_order_id: @order.id).count
  end
  test "simultaneous conflicting key reuse records exactly one input" do
    key = SecureRandom.uuid
    counter = Queue.new
    counter << "4" << "6"
    results = race { |actor| receive_order(actor, @order, receiving_attributes(@order, quantity: counter.pop, key: key)) }
    assert_equal(1, results.count { |value| value.is_a?(GoodsReceipt) })
    assert_equal(1, results.count { |value| value.is_a?(HrmProcurement::Domain::Services::RequestConflict) })
    assert_equal 1, GoodsReceipt.where(purchase_order_id: @order.id).count
  end
  test "older remaining snapshot is refreshed after another receipt commits" do
    ready, go, result = Queue.new, Queue.new, Queue.new
    @threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        begin
          ActiveRecord::Base.transaction do
            raise "Unexpected fixture lines" unless GoodsReceiptLine.where(purchase_order_id: @order.id).count.zero?
            ready << true
            go.pop
            receive_order(User.find(@buyer.id), @order, receiving_attributes(@order, quantity: "6"))
          end
          result << :received
        rescue StandardError => error
          result << error
        ensure
          Current.reset
        end
      end
    end
    Timeout.timeout(10) { ready.pop }
    receive_order(@buyer, @order, receiving_attributes(@order, quantity: "6"))
    go << true
    assert @threads.first.join(20), "Receiving lock timed out"
    assert_kind_of HrmProcurement::Domain::Services::RequestConflict, result.pop
    assert_equal BigDecimal("6"), GoodsReceiptLine.where(purchase_order_id: @order.id).sum(:quantity)
  end
  test "an older snapshot cannot bypass receiving grant revocation" do
    ready, go, result = Queue.new, Queue.new, Queue.new
    @threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        begin
          ActiveRecord::Base.transaction do
            raise "Missing fixture grant" unless @buyer.effective_permission_keys.include?("procurement.receipts.create")
            ready << true
            go.pop
            receive_order(@buyer, @order)
          end
          result << :received
        rescue StandardError => error
          result << error
        ensure
          Current.reset
        end
      end
    end
    Timeout.timeout(10) { ready.pop }
    UserPermission.create!(user: @buyer, permission: Permission.find_by!(key: "procurement.receipts.create"), granted: false)
    go << true
    assert @threads.first.join(20), "Grant lock timed out"
    assert_kind_of Pundit::NotAuthorizedError, result.pop
    assert_equal 0, GoodsReceipt.where(purchase_order_id: @order.id).count
  end
end
