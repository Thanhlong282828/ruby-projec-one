class CostCenter < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  has_many :organization_units, dependent: :restrict_with_error
  validates :code, presence: true, length: { maximum: 30 }, format: { with: /\A[A-Za-z0-9_-]+\z/ }, uniqueness: { scope: :company_id }
  validates :name, presence: true, length: { maximum: 255 }
  validates :annual_budget, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, inclusion: { in: %w[VND USD EUR JPY SGD AUD GBP] }
end
