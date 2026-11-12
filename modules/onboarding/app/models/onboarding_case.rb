class OnboardingCase < ApplicationRecord
  BOOLEAN_VALUES = [ true, false ].freeze
  include CompanyOwned
  include ObservableRecord
  belongs_to :employee
  validates :start_date, presence: true, uniqueness: { scope: [ :company_id, :employee_id ] }
  validates :status, inclusion: { in: HrmOnboarding::Domain::Services::CaseStateMachine::TRANSITIONS.keys }
  validate :valid_start_date
  validate :same_company_employee
  validate :immutable_identity, on: :update
  validate :valid_checklist
  def public_attributes = attributes.slice("id", "employee_id", "start_date", "status", "checklist", "lock_version")
  private
  def valid_start_date
    raw = start_date_before_type_cast
    return if raw.is_a?(Date) || (raw.is_a?(String) && /\A\d{4}-\d{2}-\d{2}\z/.match?(raw) && Date.iso8601(raw))
    errors.add(:start_date, "phải là ngày ISO hợp lệ")
  rescue Date::Error
    errors.add(:start_date, "phải là ngày ISO hợp lệ")
  end
  def same_company_employee
    errors.add(:employee, "phải thuộc company") if employee && employee.company_id != company_id
  end
  def immutable_identity
    errors.add(:base, "Không được đổi nhân viên/ngày bắt đầu") if will_save_change_to_employee_id? || will_save_change_to_start_date?
  end
  def valid_checklist
    valid = checklist.is_a?(Array) && checklist.length.between?(1, 30) && checklist.all? { |item| item.is_a?(Hash) && item["code"].is_a?(String) && item["title"].is_a?(String) && BOOLEAN_VALUES.include?(item["done"]) && BOOLEAN_VALUES.include?(item["required"]) }
    errors.add(:checklist, "không hợp lệ") unless valid
  end
end
