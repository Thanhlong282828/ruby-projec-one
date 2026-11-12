class WorkShift < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  has_many :employee_shift_assignments, dependent: :restrict_with_error
  normalizes :code, with: ->(value) { value.to_s.strip.upcase }
  validates :code, presence: true, length: { maximum: 30 }, format: { with: /\A[A-Z0-9_-]+\z/ }, uniqueness: { scope: :company_id }
  validates :name, presence: true, length: { maximum: 255 }
  validates :start_minute, :end_minute, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 1440 }
  validates :unpaid_break_minutes, :grace_in_minutes, :grace_out_minutes, :overtime_threshold_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [ true, false ] }
  validate :valid_rules

  def start_time = clock_label(start_minute)
  def end_time = clock_label(end_minute)
  def start_time=(value)
    self.start_minute = parse_clock(value)
  end
  def end_time=(value)
    self.end_minute = parse_clock(value)
  end
  def crosses_midnight? = start_minute && end_minute && end_minute < start_minute
  def duration_minutes = start_minute && end_minute && ((end_minute - start_minute) % 1440)
  def planned_work_minutes = duration_minutes && (duration_minutes - unpaid_break_minutes.to_i)
  def public_attributes
    attributes.slice("id", "code", "name", "unpaid_break_minutes", "grace_in_minutes", "grace_out_minutes", "overtime_threshold_minutes", "active", "lock_version").merge(
      "start_time" => start_time, "end_time" => end_time, "crosses_midnight" => crosses_midnight?, "planned_work_minutes" => planned_work_minutes)
  end
  private
  def parse_clock(value)
    return unless value.is_a?(String) && /\A(?:[01]\d|2[0-3]):[0-5]\d\z/.match?(value)
    hour, minute = value.split(":").map(&:to_i)
    (hour * 60) + minute
  end
  def clock_label(value) = value && format("%02d:%02d", value / 60, value % 60)
  def valid_rules
    return unless start_minute.is_a?(Integer) && end_minute.is_a?(Integer)
    errors.add(:end_time, "phải khác giờ bắt đầu") if start_minute == end_minute
    duration = duration_minutes
    if unpaid_break_minutes.is_a?(Integer) && unpaid_break_minutes >= duration
      errors.add(:unpaid_break_minutes, "phải nhỏ hơn độ dài ca")
    end
    [ :grace_in_minutes, :grace_out_minutes, :overtime_threshold_minutes ].each do |field|
      errors.add(field, "không được vượt độ dài ca") if self[field].is_a?(Integer) && self[field] > duration
    end
  end
end
