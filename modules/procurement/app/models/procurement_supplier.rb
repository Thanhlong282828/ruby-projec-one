class ProcurementSupplier < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  has_many :purchase_orders, foreign_key: :supplier_id, inverse_of: :supplier, dependent: :restrict_with_exception
  validates :code, presence: true, length: { maximum: 40 }, uniqueness: { scope: :company_id }, format: { with: /\A[A-Z0-9][A-Z0-9_-]*\z/ }
  validates :name, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: %w[active inactive] }
  validate { errors.add(:company_id, "không được đổi") if persisted? && will_save_change_to_company_id? }
  before_destroy { throw :abort }
end
