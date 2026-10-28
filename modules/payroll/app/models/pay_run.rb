class PayRun < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :created_by, class_name: "User"
  has_many :payslips, dependent: :restrict_with_error
  enum :status, { draft: "draft", finalized: "finalized" }, validate: true
  validates :period, presence: true, uniqueness: { scope: :company_id }
  before_validation { self.period = period.beginning_of_month if period }
  before_validation { self.company_id ||= created_by&.company_id }
  validate { same_company_as(:created_by) }

end
