require_relative "return_fixtures"
module ReversalFixtures
  include ReturnFixtures
  def reversal_attributes(key: SecureRandom.uuid, reason: "Sửa sai phiếu trả")
    { idempotency_key: key, reason: reason }
  end
  def reverse_stock(actor, record, attributes = reversal_attributes)
    purchase_commands::PostStockReturnReversal.new.call(actor: actor, id: record.id, attributes: attributes)
  end
  def reversal_source(actor, record)
    HrmProcurement::Application::Queries::StockReturnReversalSource.new.call(actor: actor, id: record.id)
  end
  def find_reversal(actor, record)
    HrmProcurement::Application::Queries::FindStockReturnReversal.new.call(actor: actor, id: record.id)
  end
end
