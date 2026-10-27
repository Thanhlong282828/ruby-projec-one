class PayRun < ApplicationRecord
  include ObservableRecord
  belongs_to :created_by, class_name: "User"
  has_many :payslips, dependent: :restrict_with_error
  enum :status, { draft: "draft", finalized: "finalized" }, validate: true
  validates :period, presence: true, uniqueness: true
  before_validation { self.period = period.beginning_of_month if period }
end
