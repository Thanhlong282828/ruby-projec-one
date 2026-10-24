class LeaveRequest < ApplicationRecord
  include ObservableRecord
  belongs_to :employee
  belongs_to :reviewer, class_name: "User", optional: true
  enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }, validate: true
  validates :starts_on, :ends_on, :reason, presence: true
  validates :reason, length: { maximum: 2000 }
  validate :valid_dates
  validate :no_overlap, on: :create
  def days = Hrm::Calendar.inclusive_days(starts_on, ends_on)
  private
  def valid_dates
    return unless starts_on && ends_on
    errors.add(:ends_on, "must be on or after start") if ends_on < starts_on
    errors.add(:ends_on, "must be in the same year") if starts_on.year != ends_on.year
  end
  def no_overlap
    return unless starts_on && ends_on && employee
    overlap = employee.leave_requests.where(status: %w[pending approved]).where("starts_on <= ? AND ends_on >= ?", ends_on, starts_on)
    errors.add(:base, "Overlapping leave request") if overlap.exists?
  end
end
