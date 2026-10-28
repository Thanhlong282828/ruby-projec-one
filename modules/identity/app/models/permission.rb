class Permission < ApplicationRecord
  has_many :role_permissions, dependent: :restrict_with_error
  has_many :user_permissions, dependent: :restrict_with_error
  validates :key, :name, presence: true
  validates :key, uniqueness: true
end
