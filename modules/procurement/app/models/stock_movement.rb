class StockMovement < ApplicationRecord
  include CompanyOwned
  belongs_to :stock_receipt, inverse_of: :movements
  belongs_to :goods_receipt_line
  belongs_to :purchase_order_line
  belongs_to :warehouse
  belongs_to :stock_item
  validates :quantity, numericality: { greater_than: 0 }
  validates :item_code_snapshot, :item_name_snapshot, :unit, presence: true
  validate { same_company_as(:stock_receipt, :goods_receipt_line, :purchase_order_line, :warehouse, :stock_item) }
  before_update { throw :abort }
  before_destroy { throw :abort }
end
