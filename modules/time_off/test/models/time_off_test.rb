require "test_helper"
class TimeOffDomainTest < ActiveSupport::TestCase
  test "leave rejects reversed dates and overlapping intervals" do
    employee = make_employee
    TimeOff::Submit.call(employee: employee, attributes: { starts_on: Date.new(2026, 11, 1), ends_on: Date.new(2026, 11, 3), reason: "Holiday" })
    overlap = employee.leave_requests.new(starts_on: Date.new(2026, 11, 3), ends_on: Date.new(2026, 11, 5), reason: "Holiday")
    assert_not overlap.valid?
    invalid = employee.leave_requests.new(starts_on: Date.new(2026, 11, 8), ends_on: Date.new(2026, 11, 5), reason: "Holiday")
    assert_not invalid.valid?
  end
  test "leave review prevents self approval and repeated transition" do
    employee = make_employee(make_user(:hr))
    request = employee.leave_requests.create!(starts_on: Date.new(2026, 11, 1), ends_on: Date.new(2026, 11, 2), reason: "Family")
    assert_raises(Pundit::NotAuthorizedError) { TimeOff::Review.call(request: request, reviewer: employee.user, decision: "approved") }
    reviewer = make_user(:hr)
    TimeOff::Review.call(request: request, reviewer: reviewer, decision: "approved")
    assert request.reload.approved?
    assert_equal reviewer.id, request.reviewer_id
    assert_raises(TimeOff::Review::InvalidTransition) { TimeOff::Review.call(request: request, reviewer: reviewer, decision: "rejected") }
  end
  test "leave review enforces yearly balance" do
    employee = make_employee(annual_leave_days: 1)
    request = employee.leave_requests.create!(starts_on: Date.new(2026, 11, 1), ends_on: Date.new(2026, 11, 2), reason: "Family")
    assert_raises(TimeOff::Review::InvalidTransition) { TimeOff::Review.call(request: request, reviewer: make_user(:hr), decision: "approved") }
    assert request.reload.pending?
  end
end
