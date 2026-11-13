require_relative "procurement_fixtures"
module OrderFixtures
  include ProcurementFixtures
  def supplier_for(actor, code: "SAMPLE", name: "Sample supplier", status: "active")
    purchase_commands::SaveSupplier.new.call(actor: actor, attributes: { code: code, name: name, status: status })
  end
  def approved_source(maker, checker, attributes: purchase_attributes)
    record = purchase_commands::CreateRequest.new.call(actor: maker, attributes: attributes)
    record = submit_purchase(maker, record)
    decide_purchase(checker, record)
  end
  def create_order(actor, source, supplier, date: "2026-12-01")
    purchase_commands::CreateOrder.new.call(actor: actor, purchase_request_id: source.id, supplier_id: supplier.id, expected_on: date)
  end
  def order_attributes(record, prices: nil, reason: nil)
    { expected_on: "2026-12-02", price_change_reason: reason,
      items: record.lines.map.with_index { |line, index| { "source_line_id" => line.source_line_id.to_s, "unit_price" => prices ? prices.fetch(index) : line.unit_price.to_i.to_s } } }
  end
  def update_order(actor, record, attributes, version: record.lock_version)
    purchase_commands::UpdateOrder.new.call(actor: actor, id: record.id, attributes: attributes, lock_version: version)
  end
  def issue_order(actor, record, version: record.lock_version)
    purchase_commands::IssueOrder.new.call(actor: actor, id: record.id, lock_version: version)
  end
end
