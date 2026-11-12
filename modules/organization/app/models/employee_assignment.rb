class EmployeeAssignment < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :employee
  belongs_to :organization_unit
  belongs_to :job_position
  validates :effective_from, presence: true
  validates :allocation_percent, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validate do
    same_company_as(:employee, :organization_unit, :job_position)
    errors.add(:organization_unit_id, "không khớp đơn vị của vị trí") if job_position && job_position.organization_unit_id != organization_unit_id
    errors.add(:effective_to, "phải từ ngày bắt đầu trở đi") if effective_from && effective_to && effective_to < effective_from
    if employee && !(employee.active? || employee.probation?)
      errors.add(:employee_id, "nhân viên đã ngừng làm việc")
    end
    errors.add(:effective_from, "trước ngày vào làm") if employee && effective_from && effective_from < employee.hired_on
    if organization_unit && effective_from
      errors.add(:effective_from, "trước ngày hiệu lực đơn vị") if effective_from < organization_unit.effective_from
      if organization_unit.effective_to && (effective_to.nil? || effective_to > organization_unit.effective_to)
        errors.add(:effective_to, "vượt thời hạn hiệu lực đơn vị")
      end
    end
    next unless effective_from && employee && job_position && allocation_percent
    intervals = EmployeeAssignment.where(company_id: company_id, employee_id: employee_id).where.not(id: id).pluck(:effective_from, :effective_to, :allocation_percent)
    if HrmOrganization::Domain::Services::IntervalCapacity.peak(intervals + [ [ effective_from, effective_to, allocation_percent ] ]) > 100
      errors.add(:allocation_percent, "tổng phân bổ vượt 100% trong khoảng hiệu lực")
    end
    occupants = EmployeeAssignment.where(company_id: company_id, job_position_id: job_position_id).where.not(id: id).pluck(:effective_from, :effective_to).map { |a, b| [ a, b, 1 ] }
    if HrmOrganization::Domain::Services::IntervalCapacity.peak(occupants + [ [ effective_from, effective_to, 1 ] ]) > job_position.approved_headcount
      errors.add(:job_position_id, "vượt định biên được duyệt")
    end
  end
end
