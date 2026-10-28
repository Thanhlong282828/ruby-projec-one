require "test_helper"
class LeaveUseCasesTest < ActiveSupport::TestCase
  class FailingEventRepository < HrmPlatform::Domain::Repositories::OutboxRepositoryInterface
    def append!(company_id:, event_type:, payload:) = raise(IOError, "outbox unavailable")
  end
  test "event failure rolls back review and its audit writes" do
    employee = make_employee
    reviewer = make_user(:hr)
    request = HrmTimeOff::Application::Commands::SubmitLeave.new.call(actor: employee.user, employee_id: employee.id, attributes: { starts_on: Date.new(2026, 11, 4), ends_on: Date.new(2026, 11, 5), reason: "Family" })
    before_counts = [AuditLog.count, OutboxEvent.count]
    command = HrmTimeOff::Application::Commands::ReviewLeave.new(events: FailingEventRepository.new)
    assert_raises(IOError) { command.call(request: request, reviewer: reviewer, decision: "approved") }
    assert request.reload.pending?
    assert_nil request.reviewed_at
    assert_equal before_counts, [AuditLog.count, OutboxEvent.count]
  end
  test "employee cannot submit leave for someone outside own scope" do
    employee = make_employee
    other = make_employee
    assert_raises(ActiveRecord::RecordNotFound) do
      HrmTimeOff::Application::Commands::SubmitLeave.new.call(actor: employee.user, employee_id: other.id, attributes: { starts_on: Date.current, ends_on: Date.current, reason: "Family" })
    end
    assert_equal 0, other.leave_requests.count
  end
end
