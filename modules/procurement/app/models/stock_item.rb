class StockItem < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  validates :code, presence: true, uniqueness: { scope: :company_id }, length: { maximum: 40 }
  validates :name, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: %w[active inactive] }
  validates :unit, presence: true, length: { maximum: 30 }
  validate do
    immutable = %w[company_id code unit]
    errors.add(:base, "Mã ổn định và đơn vị không được đổi; hãy tạo mã mới") if persisted? && immutable.any? { |key| will_save_change_to_attribute?(key) }
  end
  before_destroy { throw :abort }
end
