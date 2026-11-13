require_relative "order_fixtures"
module ReceiptFixtures
  include OrderFixtures
  def receiving_attributes(order, quantity: "4", key: SecureRandom.uuid)
    { idempotency_key: key, received_on: "2026-11-13", delivery_reference: "DELIVERY-SAMPLE", items: [ { "purchase_order_line_id" => order.lines.first.id.to_s, "quantity" => quantity } ] }
  end
  def receive_order(actor, order, attributes = receiving_attributes(order))
    purchase_commands::ReceiveOrder.new.call(actor: actor, id: order.id, attributes: attributes)
  end
  def receipt_order(maker, buyer, date: "2026-11-01")
    attrs = purchase_attributes.merge(items: [ { description: "Hàng mẫu", quantity: "10", unit: "cái", estimated_unit_price: "1000" } ])
    source = approved_source(maker, buyer, attributes: attrs)
    issue_order(buyer, create_order(buyer, source, supplier_for(buyer, code: "R#{SecureRandom.hex(4)}"), date: date))
  end
end
