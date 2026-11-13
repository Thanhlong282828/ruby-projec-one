require_relative "stock_fixtures"
module ReturnFixtures
  include StockFixtures
  def return_attributes(entry, quantity: "3", key: SecureRandom.uuid, reason: "Hàng lỗi kiểm chứng")
    { idempotency_key: key, reason: reason, items: [ { "stock_movement_id" => entry.movements.first.id.to_s, "quantity" => quantity } ] }
  end
  def return_stock(actor, entry, attributes = return_attributes(entry))
    purchase_commands::PostStockReturn.new.call(actor: actor, id: entry.id, attributes: attributes)
  end
  def return_source(actor, entry)
    HrmProcurement::Application::Queries::StockReturnSource.new.call(actor: actor, id: entry.id)
  end
  def stock_ledger_for(actor, warehouse, item, page: 1)
    HrmProcurement::Application::Queries::StockLedger.new.call(actor: actor, warehouse_id: warehouse.id, stock_item_id: item.id, page: page)
  end
end
