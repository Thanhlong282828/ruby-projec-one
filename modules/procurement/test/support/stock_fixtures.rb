require_relative "receipt_fixtures"
module StockFixtures
  include ReceiptFixtures
  def stock_catalog(actor, kind, code: "SAMPLE", unit: "cái", status: "active")
    purchase_commands::SaveStockCatalog.new.call(actor: actor, kind: kind, attributes: { code: code, name: "Sample #{kind}", unit: unit, status: status })
  end
  def stock_attributes(receipt, warehouse, item)
    { warehouse_id: warehouse.id.to_s, items: receipt.lines.map { |line| { "goods_receipt_line_id" => line.id.to_s, "stock_item_id" => item.id.to_s } } }
  end
  def post_stock(actor, receipt, warehouse, item, attributes: stock_attributes(receipt, warehouse, item))
    purchase_commands::PostStockReceipt.new.call(actor: actor, id: receipt.id, attributes: attributes)
  end
  def catalog_update(actor, record, kind, **changes)
    attributes = record.attributes.symbolize_keys.slice(:code, :name, :status, :unit).merge(changes)
    purchase_commands::SaveStockCatalog.new.call(actor: actor, kind: kind, id: record.id, lock_version: record.lock_version, attributes: attributes)
  end
  def stock_query = Hrm::Container.resolve(HrmProcurement::Domain::Repositories::ReadRepositoryInterface)
  def balances(actor, warehouse = nil)
    stock_query.stock_balances(actor: actor, filters: { page: 1, warehouse_id: warehouse&.id }.compact)
  end
end
