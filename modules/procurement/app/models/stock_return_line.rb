class StockReturnLine < ApplicationRecord
  include CompanyOwned
  belongs_to :stock_return, inverse_of: :lines
  belongs_to :stock_receipt
  belongs_to :stock_movement
  belongs_to :warehouse
  belongs_to :stock_item
  validates :quantity, numericality: { greater_than: 0 }
  validates :item_code_snapshot, :item_name_snapshot, :unit, presence: true
  validate { same_company_as(:stock_return, :stock_receipt, :stock_movement, :warehouse, :stock_item) }
  before_update { throw :abort }
  before_destroy { throw :abort }
end
