require "test_helper"
class AttendancePeriodReportTest < ActiveSupport::TestCase
  def setup
    super
    @query = HrmAttendance::Application::Queries::PeriodReport.new
    @employee = make_employee
    @day = Date.new(2026, 11, 10)
  end
  def record(employee: @employee, day: @day, hours: 8)
    at = Time.zone.local(day.year, day.month, day.day, 22)
    employee.attendances.create!(work_date: day, checked_in_at: at,
      checked_out_at: hours && (at + hours.hours))
  end
  def report(actor: @employee.user, **options)
    @query.call(actor: actor, from: @day.to_s, to: @day.to_s, **options)
  end
  test "overnight elapsed time is counted against check in date" do
    row = record(hours: 8.5)
    result = report
    assert_equal 510, result[:summary][:elapsed_minutes]
    assert_equal 510, result[:rows].first[:elapsed_minutes]
    assert_equal row.id, result[:rows].first[:id]
    assert_equal "closed", result[:rows].first[:status]
  end
  test "open sessions do not invent worked minutes and long closed sessions are flagged" do
    record(hours: nil)
    other = make_employee(make_user(:employee))
    record(employee: other, hours: 17)
    result = report(actor: make_user(:admin))
    assert_equal 2, result[:summary][:total]
    assert_equal 1, result[:summary][:open]
    assert_equal 1, result[:summary][:excessive]
    assert_equal 1020, result[:summary][:elapsed_minutes]
    assert_nil result[:rows].find { |row| row[:status] == "open" }[:elapsed_minutes]
  end
  test "employee sees own attendance only and cannot select another company" do
    own = record
    record(employee: make_employee)
    company = Company.create!(code: "OTHER#{SecureRandom.hex(3).upcase}", name: "Other")
    record(employee: make_employee(make_user(:employee, company: company)))
    assert_equal([ own.id ], report[:rows].pluck(:id))
    assert_equal 1, report[:summary][:total]
    assert_equal 2, report(actor: make_user(:admin))[:summary][:total]
  end
  test "revoked read permission prevents direct query even for stale actor" do
    actor = @employee.user
    permission = Permission.find_by!(key: "attendance.read")
    UserPermission.create!(user: actor, permission: permission, granted: false)
    assert_raises(Pundit::NotAuthorizedError) { report(actor: actor) }
  end
  test "period rejects malformed impossible reversed and too broad dates" do
    [ [ "2026-02-30", "2026-03-01" ], [ "2026-11-12", "2026-11-10" ],
      [ "2026-01-01", "2026-12-31" ], [ "2026-1-1", "2026-01-02" ],
      [ "x' OR 1=1", "2026-11-10" ], [ [ "2026-11-10" ], "2026-11-10" ] ].each do |from, to|
      assert_raises(HrmAttendance::Application::Queries::PeriodReport::InvalidPeriod) do
        @query.call(actor: @employee.user, from: from, to: to)
      end
    end
  end
  test "93 inclusive days allowed and 94 rejected" do
    first = Date.new(2026, 1, 1)
    assert_equal 0, @query.call(actor: @employee.user, from: first.to_s, to: (first + 92).to_s)[:summary][:total]
    assert_raises(HrmAttendance::Application::Queries::PeriodReport::InvalidPeriod) do
      @query.call(actor: @employee.user, from: first.to_s, to: (first + 93).to_s)
    end
  end
  test "summary spans all pages and rows have deterministic pagination" do
    26.times { |_i| record(employee: make_employee, hours: 1) }
    actor = make_user(:admin)
    first = report(actor: actor)
    second = report(actor: actor, page: 2)
    assert_equal 25, first[:rows].size
    assert_equal 1, second[:rows].size
    assert_equal 26, second[:summary][:total]
    assert_equal 1560, second[:summary][:elapsed_minutes]
    assert_empty first[:rows].pluck(:id) & second[:rows].pluck(:id)
  end
  test "no employee source link without employee read permission" do
    record
    actor = @employee.user
    UserPermission.create!(user: actor,
      permission: Permission.find_by!(key: "employees.read"), granted: false)
    assert_nil report(actor: actor)[:rows].first[:employee_path]
  end
  test "open previous day blocks next check in until checkout and retries preserve first checkout" do
    check_in = HrmAttendance::Application::Commands::CheckIn.new
    check_out = HrmAttendance::Application::Commands::CheckOut.new
    at = Time.zone.local(2026, 11, 10, 22)
    row = check_in.call(actor: @employee.user, at: at)
    assert_raises(HrmAttendance::Domain::Services::AttendanceCaptureService::InvalidState) do
      check_in.call(actor: @employee.user, at: at + 1.day)
    end
    assert_equal 1, @employee.attendances.count
    check_out.call(actor: @employee.user, id: row.id, at: at + 8.hours)
    check_out.call(actor: @employee.user, id: row.id, at: at + 9.hours)
    assert_equal at + 8.hours, row.reload.checked_out_at
    assert check_in.call(actor: @employee.user, at: at + 1.day).persisted?
  end
  test "date filters exclude adjacent days and exactly 16 hours is not excessive" do
    record(hours: 16)
    record(day: @day - 1, hours: 17)
    record(day: @day + 1, hours: 17)
    result = report
    assert_equal 1, result[:summary][:total]
    assert_equal 960, result[:summary][:elapsed_minutes]
    assert_equal 0, result[:summary][:excessive]
    assert_equal "closed", result[:rows].first[:status]
  end
  test "deactivated actor cannot read report through application entrypoint" do
    @employee.user.update!(active: false)
    assert_raises(Pundit::NotAuthorizedError) { report }
  end
end
