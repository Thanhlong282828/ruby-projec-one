require "test_helper"
class AttendanceDomainTest < ActiveSupport::TestCase
  test "attendance is unique per employee per day" do
    employee = make_employee
    employee.attendances.create!(work_date: Date.current, checked_in_at: Time.current)
    assert_not employee.attendances.new(work_date: Date.current, checked_in_at: Time.current).valid?
  end
end
