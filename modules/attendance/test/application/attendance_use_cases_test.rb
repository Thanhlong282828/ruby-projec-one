require "test_helper"
class AttendanceUseCasesTest < ActiveSupport::TestCase
  class FakeReadRepository < HrmAttendance::Domain::Repositories::ReadRepositoryInterface
    attr_reader :received
    def list(actor:, page:)
      @received = [actor.id, page]
      [:from_fake_repository]
    end
  end
  test "query accepts a repository double through constructor injection" do
    actor = make_user
    repository = FakeReadRepository.new
    result = HrmAttendance::Application::Queries::ListAttendances.new(repository: repository).call(actor: actor, page: 2)
    assert_equal [:from_fake_repository], result
    assert_equal [actor.id, 2], repository.received
  end
  test "check in and check out go through the real bound repositories" do
    employee = make_employee
    at = Time.zone.local(2026, 10, 26, 8)
    record = HrmAttendance::Application::Commands::CheckIn.new.call(actor: employee.user, at: at)
    assert record.persisted?
    assert_equal employee.id, record.employee_id
    HrmAttendance::Application::Commands::CheckOut.new.call(actor: employee.user, id: record.id, at: at + 8.hours)
    assert_equal at + 8.hours, record.reload.checked_out_at
  end
  test "duplicate check in cannot create a second daily record" do
    employee = make_employee
    command = HrmAttendance::Application::Commands::CheckIn.new
    command.call(actor: employee.user)
    assert_raises(HrmAttendance::Domain::Services::AttendanceCaptureService::InvalidState) { command.call(actor: employee.user) }
    assert_equal 1, employee.attendances.count
  end
  test "inactive employee cannot check in even if login account remains active" do
    employee = make_employee(status: :inactive)
    assert_raises(HrmAttendance::Domain::Services::AttendanceCaptureService::InvalidState) do
      HrmAttendance::Application::Commands::CheckIn.new.call(actor: employee.user)
    end
    assert_equal 0, employee.attendances.count
  end
  test "an employee cannot check out another employee's record" do
    employee = make_employee
    other = make_employee
    record = HrmAttendance::Application::Commands::CheckIn.new.call(actor: other.user)
    assert_raises(ActiveRecord::RecordNotFound) do
      HrmAttendance::Application::Commands::CheckOut.new.call(actor: employee.user, id: record.id)
    end
    assert_nil record.reload.checked_out_at
  end
  test "deactivated actor cannot invoke a query directly" do
    actor = make_user
    actor.update!(active: false)
    assert_raises(Pundit::NotAuthorizedError) { HrmAttendance::Application::Queries::ListAttendances.new.call(actor: actor) }
  end
  test "list query prepares employee associations before the view renders" do
    employee = make_employee
    HrmAttendance::Application::Commands::CheckIn.new.call(actor: employee.user)
    rows = HrmAttendance::Application::Queries::ListAttendances.new.call(actor: employee.user)
    assert_kind_of Array, rows
    queries = []
    subscriber = ->(*args) { queries << args.last[:sql] unless %w[SCHEMA TRANSACTION].include?(args.last[:name]) }
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      rows.each { |row| [row.employee.full_name, row.work_date] }
    end
    assert_empty queries
  end

end
