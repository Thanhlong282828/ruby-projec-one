class PurchaseOrderLine < ApplicationRecord
  include CompanyOwned
  belongs_to :purchase_order, inverse_of: :lines
  belongs_to :purchase_request
  belongs_to :source_line, class_name: "PurchaseRequestLine"
  validates :description, :unit, presence: true
  validates :unit_price, numericality: { greater_than_or_equal_to: 0, less_than: 1_000_000_000_000 }
  validate do
    same_company_as(:purchase_order, :purchase_request, :source_line)
    expected = (quantity * unit_price).round(0, BigDecimal::ROUND_HALF_UP) if quantity && unit_price
    errors.add(:line_total, "không khớp số lượng và giá") unless expected && expected == line_total
  end
end
