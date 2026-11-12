class JobPosition < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :organization_unit
  has_many :employee_assignments, dependent: :restrict_with_error
  validates :code, presence: true, length: { maximum: 30 }, format: { with: /\A[A-Za-z0-9_-]+\z/ }, uniqueness: { scope: :company_id }
  validates :title, presence: true, length: { maximum: 255 }
  validates :job_grade, length: { maximum: 50 }, allow_nil: true
  validates :career_level, inclusion: { in: 1..6 }
  validates :approved_headcount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :budgeted_cost, numericality: { greater_than_or_equal_to: 0 }
  validates :is_critical, inclusion: { in: [ true, false ] }
  validate do
    same_company_as(:organization_unit)
    if persisted? && will_save_change_to_organization_unit_id? && employee_assignments.exists?
      errors.add(:organization_unit_id, "không thể chuyển vị trí đã có lịch sử phân công")
    end
    if persisted? && approved_headcount && approved_headcount < HrmOrganization::Domain::Services::IntervalCapacity.peak(employee_assignments.pluck(:effective_from, :effective_to).map { |a, b| [ a, b, 1 ] })
      errors.add(:approved_headcount, "thấp hơn số nhân sự đã phân công")
    end
  end
end
