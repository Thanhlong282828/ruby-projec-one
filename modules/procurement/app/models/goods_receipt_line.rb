class GoodsReceiptLine < ApplicationRecord
  include CompanyOwned
  belongs_to :goods_receipt, inverse_of: :lines
  belongs_to :purchase_order_line
  validates :quantity, numericality: { greater_than: 0, less_than_or_equal_to: BigDecimal("999999.999") }
  validate { same_company_as(:goods_receipt, :purchase_order_line) }
  before_update { throw :abort }
  before_destroy { throw :abort }
end
