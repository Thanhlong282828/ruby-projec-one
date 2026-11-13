require "test_helper"
require "minitest/mock"
require_relative "../support/reversal_fixtures"

class StockReturnReversalsTest < ActionDispatch::IntegrationTest
  include ReversalFixtures
  def setup
    @buyer = make_user(:manager)
    @maker = make_user(:employee)
    @order = receipt_order(@maker, @buyer)
    @warehouse = stock_catalog(@buyer, :warehouse)
    @item = stock_catalog(@buyer, :item)
    @entry = post_stock(@buyer, receive_order(@buyer, @order), @warehouse, @item)
    @second = post_stock(@buyer, receive_order(@buyer, @order, receiving_attributes(@order, quantity: "6")), @warehouse, @item)
    @source = return_stock(@buyer, @entry)
    @conflict = HrmProcurement::Domain::Services::RequestConflict
    @invalid = HrmProcurement::Domain::Services::RequestContent::Invalid
  end
  test "full reversal restores stock and per movement entitlement without changing sources" do
    originals = [ @entry, @source, @source.lines.first, @entry.movements.first ].map(&:attributes)
    record = reverse_stock(@buyer, @source)
    assert_equal "posted", record.status
    assert_equal @source.id, record.stock_return_id
    assert_equal @source.lines.first.id, record.lines.first.stock_return_line_id
    assert_equal BigDecimal("3"), record.lines.first.quantity
    assert_equal BigDecimal("10"), balances(@buyer, @warehouse)[:records].first[:quantity]
    assert_equal BigDecimal("4"), return_source(@buyer, @entry)[:lines].first[:remaining]
    assert_equal BigDecimal("0"), return_source(@buyer, @entry)[:lines].first[:returned]
    ledger = stock_ledger_for(@buyer, @warehouse, @item)
    assert_equal 4, ledger[:count]
    assert_equal BigDecimal("10"), ledger[:quantity]
    assert_equal %w[receipt receipt return reversal], ledger[:records].pluck(:document_kind).sort
    assert_equal [ BigDecimal("-3"), BigDecimal("3"), BigDecimal("4"), BigDecimal("6") ], ledger[:records].map(&:quantity).sort
    assert_equal(originals, [ @entry, @source, @source.lines.first, @entry.movements.first ].map { |s| s.reload.attributes })
    return_stock(@buyer, @entry, return_attributes(@entry, quantity: "4"))
    assert_equal BigDecimal("6"), balances(@buyer, @warehouse)[:records].first[:quantity]
    assert_raises(@conflict) { return_stock(@buyer, @entry, return_attributes(@entry, quantity: "0.001")) }
  end
  test "reversing only three leaves the separate one effective" do
    effective = return_stock(@buyer, @entry, return_attributes(@entry, quantity: "1"))
    reverse_stock(@buyer, @source)
    row = return_source(@buyer, @entry)[:lines].first
    assert_equal BigDecimal("1"), row[:returned]
    assert_equal BigDecimal("3"), row[:remaining]
    assert_equal BigDecimal("9"), balances(@buyer, @warehouse)[:records].first[:quantity]
    assert_equal "posted", effective.reload.status
    return_stock(@buyer, @entry)
    assert_equal BigDecimal("0"), return_source(@buyer, @entry)[:lines].first[:remaining]
  end
  test "replay is canonical read only and conflicting keys or a second reversal fail" do
    attrs = reversal_attributes
    record = reverse_stock(@buyer, @source, attrs)
    other = return_stock(@buyer, @second)
    assert_no_difference([ "StockReturnReversal.count", "StockReturnReversalLine.count", "AuditLog.count", "OutboxEvent.count" ]) do
      assert_equal record.id, reverse_stock(@buyer, @source, attrs.merge(reason: "  #{attrs[:reason]}  ")).id
      assert_raises(@conflict) { reverse_stock(@buyer, @source, attrs.merge(reason: "khác")) }
      assert_raises(@conflict) { reverse_stock(@buyer, @source) }
      assert_raises(@conflict) { reverse_stock(@buyer, other, attrs) }
    end
  end
  test "current grants distinguish reversal read post and original return read" do
    record = reverse_stock(@buyer, @source, attrs = reversal_attributes)
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.return_reversals.post"), granted: false)
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.returns.read"), granted: false)
    assert_equal record.id, reverse_stock(@buyer, @source, attrs).id
    other = return_stock(@maker = make_user(:manager), @second)
    assert_raises(Pundit::NotAuthorizedError) { reverse_stock(@buyer, other) }
    detail = find_reversal(@buyer, record)
    assert_not detail[:source_visible]
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.return_reversals.read"), granted: false)
    assert_raises(Pundit::NotAuthorizedError) { reverse_stock(@buyer, @source, attrs) }
    assert_raises(Pundit::NotAuthorizedError) { find_reversal(@buyer, record) }
    assert_raises(Pundit::NotAuthorizedError) { reversal_source(@buyer, @source) }
  end
  test "server owns all quantities destinations and source fields and rejects malformed content" do
    [ nil, [], "", "x" ].each { |value| assert_raises(@invalid) { reverse_stock(@buyer, @source, value) } }
    malformed = "\xFF".dup.force_encoding(Encoding::UTF_8)
    [ nil, " ", [], malformed, "x" * 2001 ].each { |value| assert_raises(@invalid) { reverse_stock(@buyer, @source, reversal_attributes.merge(reason: value)) } }
    [ nil, [], "short", malformed ].each { |value| assert_raises(@invalid) { reverse_stock(@buyer, @source, reversal_attributes.merge(idempotency_key: value)) } }
    record = reverse_stock(@buyer, @source, reversal_attributes.merge(quantity: "999", warehouse_id: -1, company_id: -1, items: []))
    assert_equal @buyer.company_id, record.company_id
    assert_equal @entry.warehouse_id, record.warehouse_id
    assert_equal BigDecimal("3"), record.lines.first.quantity
    assert_equal @source.reason, @source.reload.reason
  end
  test "two companies with equal catalog codes cannot access or reverse foreign source" do
    outsider = make_user(:manager, company: Company.create!(code: "REVOTHER", name: "Other reversal company"))
    w = stock_catalog(outsider, :warehouse)
    item = stock_catalog(outsider, :item)
    assert_equal @warehouse.code, w.code
    assert_equal @item.code, item.code
    assert_raises(ActiveRecord::RecordNotFound) { reverse_stock(outsider, @source) }
    assert_raises(ActiveRecord::RecordNotFound) { reversal_source(outsider, @source) }
    record = reverse_stock(@buyer, @source)
    assert_raises(ActiveRecord::RecordNotFound) { find_reversal(outsider, record) }
    purchase_login(outsider)
    get stock_return_reversal_path(record)
    assert_response :not_found
    post stock_return_reversals_path, params: { stock_return_reversal: reversal_attributes.merge(stock_return_id: @source.id) }
    assert_response :not_found
  end
  test "reversals preserve decimals and inactive historical catalogs" do
    extra = return_stock(@buyer, @second, return_attributes(@second, quantity: "0.125"))
    reverse_stock(@buyer, extra)
    assert_equal BigDecimal("6"), return_source(@buyer, @second)[:lines].first[:remaining]
    @warehouse.update!(status: "inactive")
    @item.update!(status: "inactive")
    @source.supplier.update!(status: "inactive")
    record = reverse_stock(@buyer, @source)
    assert_equal @source.warehouse_name_snapshot, record.warehouse_name_snapshot
    assert_equal @source.supplier_name_snapshot, record.supplier_name_snapshot
    assert_equal BigDecimal("10"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
  test "audit and outbox failures after lines roll back the whole reversal" do
    [ HrmAudit::Domain::Repositories::WriteRepositoryInterface, HrmPlatform::Domain::Repositories::OutboxRepositoryInterface ].each do |contract|
      implementation = Hrm::Container.resolve(contract).class
      original = implementation.instance_method(:append!)
      implementation.define_method(:append!) do |**args|
        record = args[:record]
        if (record.is_a?(StockReturnReversal) && record.status == "posted") || args[:event_type] == "stock_return_reversal.updated"
          raise "reversal journal failed after lines"
        end
        original.bind_call(self, **args)
      end
      begin
        assert_no_difference([ "StockReturnReversal.count", "StockReturnReversalLine.count", "AuditLog.count", "OutboxEvent.count" ]) do
          assert_raises(RuntimeError) { reverse_stock(@buyer, @source) }
        end
        assert_equal BigDecimal("7"), balances(@buyer, @warehouse)[:records].first[:quantity]
        assert_equal BigDecimal("1"), return_source(@buyer, @entry)[:lines].first[:remaining]
      ensure
        implementation.define_method(:append!, original)
      end
    end
  end
  test "model SQL and composite foreign keys protect immutable source bound documents" do
    record = reverse_stock(@buyer, @source)
    assert_not record.update(reason: "changed")
    assert_not record.lines.first.update(quantity: 1)
    assert_raises(ActiveRecord::DeleteRestrictionError) { record.destroy }
    connection = ActiveRecord::Base.connection
    [ "UPDATE stock_return_reversals SET status='posting',posted_at=NULL WHERE id=#{record.id}",
      "DELETE FROM stock_return_reversals WHERE id=#{record.id}",
      "UPDATE stock_return_reversal_lines SET quantity=1 WHERE stock_return_reversal_id=#{record.id}",
      "DELETE FROM stock_return_reversal_lines WHERE stock_return_reversal_id=#{record.id}",
      "DELETE FROM purchase_orders WHERE id=#{@order.id}" ].each { |sql| assert_raises(ActiveRecord::StatementInvalid) { connection.execute(sql) } }
    raw = connection.select_value("SELECT reason FROM stock_return_reversals WHERE id=#{record.id}")
    assert_not_includes raw, record.reason
    other = return_stock(@buyer, @second)
    header = record.attributes.except("id", "created_at", "updated_at").merge("stock_return_id" => other.id, "stock_receipt_id" => @second.id, "status" => "posting", "posted_at" => nil, "code" => "RR-RAW", "idempotency_key" => SecureRandom.uuid)
    assert_raises(ActiveRecord::StatementInvalid) do
      StockReturnReversal.transaction(requires_new: true) do
        incomplete = StockReturnReversal.create!(header)
        incomplete.update!(status: "posted", posted_at: Time.current)
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      StockReturnReversal.transaction(requires_new: true) do
        wrong = StockReturnReversal.create!(header)
        values = record.lines.first.attributes.except("id", "created_at", "updated_at").merge("stock_return_reversal_id" => wrong.id, "stock_return_id" => other.id, "stock_receipt_id" => @second.id, "created_at" => Time.current, "updated_at" => Time.current)
        # rubocop:disable Rails/SkipsModelValidations -- Verify composite source FKs and guard against direct SQL bypass.
        StockReturnReversalLine.insert_all!([ values ])
        # rubocop:enable Rails/SkipsModelValidations
      end
    end
    assert_equal BigDecimal("7"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
  test "navigation confirmation and independent document links use current scopes" do
    purchase_login(@buyer)
    get stock_return_path(@source)
    assert_select "a[href=?]", new_stock_return_reversal_path(stock_return_id: @source.id), text: "Đảo phiếu trả"
    get new_stock_return_reversal_path(stock_return_id: @source.id)
    assert_response :success
    assert_select "div[role='region'][tabindex='0']"
    assert_select "textarea[required]"
    assert_select "input[name='stock_return_reversal[quantity]']", count: 0
    post stock_return_reversals_path, params: { stock_return_reversal: reversal_attributes.merge(stock_return_id: @source.id, quantity: "999") }
    record = StockReturnReversal.order(:id).last
    assert_redirected_to stock_return_reversal_path(record)
    follow_redirect!
    assert_select "a[href=?]", stock_return_path(@source)
    get stock_return_path(@source)
    assert_select "a[href=?]", new_stock_return_reversal_path(stock_return_id: @source.id), count: 0
    assert_select "a[href=?]", stock_return_reversal_path(record)
    get new_stock_return_reversal_path(stock_return_id: @source.id)
    assert_response :conflict
    get stock_return_reversals_path(q: record.code)
    assert_select "tbody tr", count: 1
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.return_reversals.read"), granted: false)
    get stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: @item.id)
    assert_select "tbody tr", count: 4
    assert_select "tbody", text: /Đảo phiếu trả/
    assert_select "a[href=?]", stock_return_reversal_path(record), count: 0
    get stock_return_reversal_path(record)
    assert_response :forbidden
  end
  test "anonymous CSRF validation and revoked grant fail at web entrypoints" do
    get stock_return_reversals_path
    assert_redirected_to new_session_path
    purchase_login(@buyer)
    post stock_return_reversals_path, params: {}
    assert_response :bad_request
    post stock_return_reversals_path, params: { stock_return_reversal: reversal_attributes(reason: " ").merge(stock_return_id: @source.id) }
    assert_response :unprocessable_content
    ActionController::Base.allow_forgery_protection = true
    post stock_return_reversals_path, params: { stock_return_reversal: reversal_attributes.merge(stock_return_id: @source.id) }
    assert_response :unprocessable_content
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
  test "mixed three way ledger pagination keeps global totals and stable identities" do
    14.times do
      record = return_stock(@buyer, @second, return_attributes(@second, quantity: "0.001"))
      reverse_stock(@buyer, record)
    end
    first = stock_ledger_for(@buyer, @warehouse, @item)
    last = stock_ledger_for(@buyer, @warehouse, @item, page: 2)
    assert_equal 31, first[:count]
    assert_equal 25, first[:records].size
    assert_equal 6, last[:records].size
    assert_equal BigDecimal("7"), first[:quantity]
    assert_equal first[:quantity], last[:quantity]
    keys = (first[:records] + last[:records]).map { |row| [ row[:document_kind], row.id ] }
    assert_equal 31, keys.uniq.size
    purchase_login(@buyer)
    get stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: @item.id, page: 2)
    assert_select "a[href=?]", stock_ledger_path(warehouse_id: @warehouse.id, stock_item_id: @item.id, page: 1)
    assert_select ".panel strong", text: "7.0 cái"
  end
  test "reversal metadata requires its own read grant and unique collision retries safely" do
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "realtime.read"), granted: true)
    assert Hrm::RealtimeAuthorization.allowed?(actor: @buyer, message: { type: "stock_return_reversal.updated", id: 1 })
    record = reverse_stock(@buyer, @source)
    other = return_stock(@buyer, @second)
    tokens = [ record.code.split("-").last.downcase, "abcdef012345" ]
    fresh = nil
    SecureRandom.stub(:hex, ->(*) { tokens.shift || raise("Unexpected code generation") }) do
      fresh = reverse_stock(@buyer, other)
    end
    assert_not_equal record.id, fresh.id
    @buyer.user_permissions.create!(permission: Permission.find_by!(key: "inventory.return_reversals.read"), granted: false)
    assert_not Hrm::RealtimeAuthorization.allowed?(actor: @buyer, message: { type: "stock_return_reversal.updated", id: 1 })
  end
  test "full multi line reversal seals only exact complete source and posting does not restore quantity" do
    attrs = purchase_attributes.merge(items: [ { description: "A", quantity: "1.125", unit: "cái", estimated_unit_price: "100" }, { description: "B", quantity: "0.001", unit: "cái", estimated_unit_price: "100" } ])
    order = issue_order(@buyer, create_order(@buyer, approved_source(@maker, @buyer, attributes: attrs), supplier_for(@buyer, code: "MULTIREV")))
    receipt = receive_order(@buyer, order, { idempotency_key: SecureRandom.uuid, received_on: Date.current.iso8601,
      items: order.lines.map { |line| { "purchase_order_line_id" => line.id.to_s, "quantity" => line.quantity.to_s("F") } } })
    entry = post_stock(@buyer, receipt, @warehouse, @item)
    source = return_stock(@buyer, entry, { idempotency_key: SecureRandom.uuid, reason: "Multi", items: entry.movements.map { |line| { "stock_movement_id" => line.id.to_s, "quantity" => line.quantity.to_s("F") } } })
    header = lambda do
      StockReturnReversal.create!(company: source.company, stock_return: source, stock_receipt: entry, warehouse: @warehouse, supplier: source.supplier, posted_by: @buyer,
        code: "RR-#{SecureRandom.hex(6)}", idempotency_key: SecureRandom.uuid, content_digest: "0" * 64, reason: "SQL seal check",
        warehouse_code_snapshot: source.warehouse_code_snapshot, warehouse_name_snapshot: source.warehouse_name_snapshot,
        supplier_code_snapshot: source.supplier_code_snapshot, supplier_name_snapshot: source.supplier_name_snapshot)
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      StockReturnReversal.transaction(requires_new: true) do
        pending = header.call
        original = source.lines.first
        pending.lines.create!(company: source.company, stock_return: source, stock_return_line: original, stock_receipt: entry,
          stock_movement: original.stock_movement, warehouse: @warehouse, stock_item: @item, quantity: original.quantity,
          item_code_snapshot: original.item_code_snapshot, item_name_snapshot: original.item_name_snapshot, unit: original.unit)
        assert_equal BigDecimal("0"), return_source(@buyer, entry)[:lines].first[:remaining]
        assert_equal BigDecimal("7"), balances(@buyer, @warehouse)[:records].first[:quantity]
        pending.update!(status: "posted", posted_at: Time.current)
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      StockReturnReversal.transaction(requires_new: true) do
        pending = header.call
        original = source.lines.first
        pending.lines.create!(company: source.company, stock_return: source, stock_return_line: original, stock_receipt: entry,
          stock_movement: original.stock_movement, warehouse: @warehouse, stock_item: @item, quantity: "0.1",
          item_code_snapshot: original.item_code_snapshot, item_name_snapshot: original.item_name_snapshot, unit: original.unit)
      end
    end
    record = reverse_stock(@buyer, source)
    assert_equal 2, record.lines.size
    assert_equal BigDecimal("1.126"), record.lines.sum(:quantity)
    assert_equal [ BigDecimal("0.001"), BigDecimal("1.125") ], return_source(@buyer, entry)[:lines].pluck(:remaining).sort
    assert_equal BigDecimal("8.126"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
  test "unposted returns cannot be reversed and unique source fence rejects second header" do
    attributes = @source.attributes.except("id", "created_at", "updated_at").merge("status" => "posting", "posted_at" => nil, "code" => "RT-PENDING", "idempotency_key" => SecureRandom.uuid)
    pending = StockReturn.create!(attributes)
    assert_raises(@conflict) { reverse_stock(@buyer, pending) }
    record = reverse_stock(@buyer, @source)
    assert_raises(ActiveRecord::RecordNotUnique) do
      StockReturnReversal.transaction(requires_new: true) do
        StockReturnReversal.create!(record.attributes.except("id", "created_at", "updated_at").merge("status" => "posting", "posted_at" => nil, "code" => "RR-DUPLICATE", "idempotency_key" => SecureRandom.uuid))
      end
    end
    assert_equal BigDecimal("10"), balances(@buyer, @warehouse)[:records].first[:quantity]
  end
end
