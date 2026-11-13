class PurchaseRequestLine < ApplicationRecord
  include CompanyOwned
  belongs_to :purchase_request, inverse_of: :lines
  validates :description, presence: true, length: { maximum: 500 }
  validates :unit, presence: true, length: { maximum: 30 }
  validates :quantity, numericality: { greater_than: 0, less_than: 1_000_000 }
  validates :estimated_unit_price, numericality: { greater_than_or_equal_to: 0, less_than: 1_000_000_000_000 }
  validates :position, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 50 }
  validate do
    same_company_as(:purchase_request)
    expected = (quantity * estimated_unit_price).round(0, BigDecimal::ROUND_HALF_UP) if quantity && estimated_unit_price
    errors.add(:line_total, "không khớp số lượng và đơn giá") unless expected && expected == line_total
  end
end
