require "test_helper"
class WorkShiftTest < ActiveSupport::TestCase
  def setup
    super
    @admin = make_user(:admin)
    @create = HrmAttendance::Application::Commands::CreateWorkShift.new
    @workspace = HrmAttendance::Application::Queries::WorkShiftWorkspace.new
    @preview = HrmAttendance::Application::Queries::PreviewWorkShift.new
  end
  def fields(**overrides)
    { code: "DAY", name: "Ca ngày", start_time: "08:00", end_time: "17:00", unpaid_break_minutes: 60,
      grace_in_minutes: 5, grace_out_minutes: 5, overtime_threshold_minutes: 30 }.merge(overrides)
  end
  def create(actor: @admin, **overrides) = @create.call(actor: actor, attributes: fields(**overrides))
  def attendance(user: make_user, hours: 9)
    employee = make_employee(user)
    start = Time.zone.local(2026, 11, 11, 8)
    employee.attendances.create!(work_date: start.to_date, checked_in_at: start, checked_out_at: hours && (start + hours.hours))
  end
  test "shift persists tenant company and audit outbox atomically" do
    shift = nil
    assert_difference "WorkShift.count", 1 do
      assert_difference "AuditLog.count", 1 do
        assert_difference "OutboxEvent.count", 1 do
          shift = create(company_id: @admin.company_id + 999)
        end
      end
    end
    assert_equal @admin.company_id, shift.company_id
    assert_equal @admin.id, AuditLog.where(record_type: "WorkShift", record_id: shift.id).last.actor_id
    assert_equal 480, shift.planned_work_minutes
    assert_equal "08:00", shift.start_time
  end
  test "invalid clocks and minute rules are rejected without persistence" do
    [ { start_time: "25:00" }, { end_time: "08:00" }, { unpaid_break_minutes: 540 },
      { grace_in_minutes: -1 }, { end_time: "7:30" }, { overtime_threshold_minutes: 541 } ].each do |override|
      assert_raises(ActiveRecord::RecordInvalid) { create(**override) }
    end
    assert_equal 0, WorkShift.count
  end
  test "MySQL constraints reject clock and rule bypass" do
    shift = create
    assert_raises(ActiveRecord::StatementInvalid) { WorkShift.where(id: shift.id).update_all(start_minute: 1440) } # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    assert_raises(ActiveRecord::StatementInvalid) { WorkShift.where(id: shift.id).update_all(unpaid_break_minutes: 540) } # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    assert_raises(ActiveRecord::InvalidForeignKey) { WorkShift.where(id: shift.id).update_all(company_id: -1) } # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    assert_equal 480, shift.reload.start_minute
  end
  test "codes are unique within company and scoped reads do not cross company" do
    own = create
    assert_raises(ActiveRecord::RecordInvalid) { create(code: "day") }
    other_company = Company.create!(code: "OTHER#{SecureRandom.hex(3).upcase}", name: "Other")
    other = create(actor: make_user(:admin, company: other_company))
    assert_equal [ own.id ], @workspace.call(actor: @admin)[:records].map(&:id)
    assert_raises(ActiveRecord::RecordNotFound) { @workspace.call(actor: @admin, id: other.id) }
  end
  test "new companies provision shift permissions but custom role has no implicit grants" do
    assert @admin.allowed?("work_shifts.create")
    assert make_user(:employee).allowed?("work_shifts.read")
    CompanyRole.create!(company: @admin.company, key: "custom", name: "Custom")
    actor = make_user("custom")
    assert_raises(Pundit::NotAuthorizedError) { @workspace.call(actor: actor) }
    assert_raises(Pundit::NotAuthorizedError) { create(actor: actor) }
  end
  test "employee cannot mutate shifts and revoked read takes effect immediately" do
    employee = make_user
    assert_raises(Pundit::NotAuthorizedError) { create(actor: employee) }
    employee.user_permissions.create!(permission: Permission.find_by!(key: "work_shifts.read"), granted: false)
    assert_raises(Pundit::NotAuthorizedError) { @workspace.call(actor: employee) }
  end
  test "update requires version and stale edits cannot overwrite a newer change" do
    shift = create
    command = HrmAttendance::Application::Commands::UpdateWorkShift.new
    assert_raises(ActiveRecord::RecordInvalid) { command.call(actor: @admin, id: shift.id, attributes: { name: "missing version" }) }
    updated = command.call(actor: @admin, id: shift.id, attributes: { name: "Changed", lock_version: 0, company_id: -1 })
    assert_equal 1, updated.lock_version
    assert_equal @admin.company_id, updated.company_id
    assert_raises(ActiveRecord::StaleObjectError) { command.call(actor: @admin, id: shift.id, attributes: { name: "Stale", lock_version: 0 }) }
    assert_equal "Changed", shift.reload.name
  end
  test "delete checks permission and stale version" do
    shift = create
    command = HrmAttendance::Application::Commands::DeleteWorkShift.new
    assert_raises(Pundit::NotAuthorizedError) { command.call(actor: make_user(:hr), id: shift.id, lock_version: 0) }
    assert_raises(ActiveRecord::StaleObjectError) { command.call(actor: @admin, id: shift.id, lock_version: 99) }
    command.call(actor: @admin, id: shift.id, lock_version: 0)
    assert_not WorkShift.exists?(shift.id)
  end
  test "preview uses real attendance without writing any business record" do
    shift = create
    row = attendance
    before = row.attributes
    assert_no_difference [ "WorkShift.count", "Attendance.count", "AuditLog.count", "OutboxEvent.count" ] do
      data = @preview.call(actor: @admin, id: shift.id, attendance_id: row.id)
      assert data[:preview_only]
      assert_equal 480, data[:result][:worked_minutes]
      assert_equal "present", data[:result][:status]
      assert_includes data[:attendance_path], row.work_date.iso8601
    end
    assert_equal before, row.reload.attributes
  end
  test "preview cannot read another employee or company attendance and rejects malformed id" do
    shift = create
    employee = make_user
    row = attendance
    assert_raises(ActiveRecord::RecordNotFound) { @preview.call(actor: employee, id: shift.id, attendance_id: row.id) }
    other_company = Company.create!(code: "FOREIGN", name: "Foreign")
    foreign = attendance(user: make_user(:employee, company: other_company))
    assert_raises(ActiveRecord::RecordNotFound) { @preview.call(actor: @admin, id: shift.id, attendance_id: foreign.id) }
    [ [], [ row.id ], {}, "1 OR 1=1", "-1" ].each do |id|
      assert_raises(ActiveRecord::RecordNotFound) { @preview.call(actor: @admin, id: shift.id, attendance_id: id) }
    end
  end
  test "attendance choices preserve employee ownership" do
    own_user = make_user
    own = attendance(user: own_user)
    attendance
    data = @workspace.call(actor: own_user, id: create.id)
    assert_equal [ own.id ], data[:attendance_options].map(&:last)
  end
  test "night shift preview ends on following day and incomplete check out yields zero work" do
    shift = create(start_time: "22:00", end_time: "06:00", unpaid_break_minutes: 30)
    row = attendance(hours: nil)
    start = Time.zone.local(2026, 11, 11, 22)
    row.update!(checked_in_at: start)
    data = @preview.call(actor: @admin, id: shift.id, attendance_id: row.id)
    assert_equal Date.new(2026, 11, 12), data[:scheduled_end].to_date
    assert_equal "incomplete", data[:result][:status]
    assert_equal 0, data[:result][:worked_minutes]
    row.update!(checked_out_at: start + 8.hours)
    assert_equal 450, @preview.call(actor: @admin, id: shift.id, attendance_id: row.id)[:result][:worked_minutes]
  end
end
