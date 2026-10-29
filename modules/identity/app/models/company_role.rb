class CompanyRole < ApplicationRecord
  include CompanyOwned
  has_many :role_permissions, dependent: :destroy
  has_many :permissions, through: :role_permissions
  validates :key, presence: true, uniqueness: { scope: :company_id }, length: { maximum: 64 }, format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates :name, presence: true, length: { maximum: 255 }
end
