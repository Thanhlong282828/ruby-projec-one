class Company < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :company_roles, dependent: :restrict_with_error
  validates :name, :code, presence: true, length: { maximum: 255 }
  validates :active, inclusion: { in: [true, false] }
  validates :code, uniqueness: true, format: { with: /\A[A-Z0-9_-]+\z/ }
  after_create { HrmIdentity::Domain::PermissionCatalog.install!(self) }
end
