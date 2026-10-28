class Department < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  has_many :employees, dependent: :restrict_with_error
  validates :name, :code, presence: true
  validates :code, uniqueness: { scope: :company_id }, format: { with: /\A[A-Z0-9_-]+\z/ }
end
