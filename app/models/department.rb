class Department < ApplicationRecord
  include ObservableRecord
  has_many :employees, dependent: :restrict_with_error
  validates :name, :code, presence: true
  validates :code, uniqueness: true, format: { with: /\A[A-Z0-9_-]+\z/ }
end
