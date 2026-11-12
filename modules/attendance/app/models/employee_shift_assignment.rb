class EmployeeShiftAssignment < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :employee
  belongs_to :work_shift
  validates :effective_from, presence: true
  validate { same_company_as(:employee, :work_shift) }
  validate :valid_date_inputs
  validate :valid_assignment
  def public_attributes = attributes.slice("id", "employee_id", "work_shift_id", "effective_from", "effective_to", "shift_snapshot", "lock_version")
  private
  def valid_date_inputs
    [ :effective_from, :effective_to ].each do |field|
      raw = read_attribute_before_type_cast(field)
      next if raw.nil? || raw.is_a?(Date) || (field == :effective_to && raw == "")
      unless raw.is_a?(String) && /\A\d{4}-\d{2}-\d{2}\z/.match?(raw) && self[field].is_a?(Date)
        errors.add(field, "phải là ngày hợp lệ dạng YYYY-MM-DD")
      end
    end
  end
  def valid_assignment
    [ :employee_id, :work_shift_id, :effective_from, :shift_snapshot ].each do |field|
      errors.add(field, "không được đổi sau khi tạo") if persisted? && will_save_change_to_attribute?(field)
    end
    return unless employee && effective_from.is_a?(Date) && (effective_to.nil? || effective_to.is_a?(Date))
    return if errors[:effective_from].any? || errors[:effective_to].any?
    errors.add(:effective_from, "không được trước ngày vào làm") if effective_from < employee.hired_on
    errors.add(:effective_to, "phải từ ngày bắt đầu trở đi") if effective_to && effective_to < effective_from
    errors.add(:employee, "đã ngừng làm việc") if new_record? && !(employee.active? || employee.probation?)
    overlap = self.class.where(company_id: company_id, employee_id: employee_id).where.not(id: id)
      .where("effective_to IS NULL OR effective_to >= ?", effective_from)
    overlap = overlap.where(effective_from: ..effective_to) if effective_to
    errors.add(:effective_from, "trùng khoảng hiệu lực phân ca khác") if overlap.exists?
    errors.add(:shift_snapshot, "không hợp lệ") unless shift_snapshot.is_a?(Hash) && shift_snapshot["start_minute"].is_a?(Integer)
  end
end
