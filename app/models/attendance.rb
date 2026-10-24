class Attendance < ApplicationRecord
  include ObservableRecord
  belongs_to :employee
  validates :work_date, :checked_in_at, presence: true
  validates :work_date, uniqueness: { scope: :employee_id }
  validate do
    if checked_out_at && checked_in_at && checked_out_at < checked_in_at
      errors.add(:checked_out_at, "must be after check-in")
    end
  end
end
