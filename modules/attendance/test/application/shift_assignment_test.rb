require "test_helper"
class ShiftAssignmentTest < ActiveSupport::TestCase
  def setup
    super
    @admin = make_user(:admin)
    @employee = make_employee(hired_on: Date.current - 365)
    @shift = HrmAttendance::Application::Commands::CreateWorkShift.new.call(actor: @admin,
      attributes: { code: "DAY", name: "Ca ngày", start_time: "08:00", end_time: "17:00", unpaid_break_minutes: 60 })
    @create = HrmAttendance::Application::Commands::CreateShiftAssignment.new
    @update = HrmAttendance::Application::Commands::UpdateShiftAssignment.new
    @delete = HrmAttendance::Application::Commands::DeleteShiftAssignment.new
    @workspace = HrmAttendance::Application::Queries::ShiftAssignmentWorkspace.new
    @schedule = HrmAttendance::Application::Queries::EmployeeShiftSchedule.new
  end
  def create(actor: @admin, **extra)
    @create.call(actor: actor, attributes: { employee_id: @employee.id, work_shift_id: @shift.id, effective_from: Date.current }.merge(extra))
  end
  def report(actor: @admin, **extra)
    @schedule.call(actor: actor, employee_id: @employee.id, from: Date.current.to_s, to: Date.current.to_s, **extra)
  end
  test "server snapshot tenant and actor audit are stored atomically" do
    row=nil
    assert_difference [ "EmployeeShiftAssignment.count", "AuditLog.count", "OutboxEvent.count" ], 1 do
      row=create(company_id: -1, shift_snapshot: { "start_minute"=>0 })
    end
    assert_equal @admin.company_id, row.company_id
    assert_equal 480, row.shift_snapshot["start_minute"]
    assert_equal @admin.id, AuditLog.find_by!(record_type: "EmployeeShiftAssignment", record_id: row.id).actor_id
  end
  test "overlap is inclusive at both endpoints and an adjacent interval is accepted" do
    create(effective_to: Date.current+2)
    assert_raises(ActiveRecord::RecordInvalid) { create(effective_from: Date.current+2) }
    assert create(effective_from: Date.current+3).persisted?
    assert_equal 2, EmployeeShiftAssignment.count
  end
  test "open interval conflicts with every later assignment and extending into another interval fails" do
    row=create(effective_to: Date.current+1)
    create(effective_from: Date.current+2)
    assert_raises(ActiveRecord::RecordInvalid) { @update.call(actor: @admin, id: row.id, attributes: { effective_to: nil, lock_version: 0 }) }
    assert_equal Date.current+1, row.reload.effective_to
  end
  test "assignment identity start and snapshot cannot be rewritten" do
    row=create
    assert_raises(ActiveRecord::RecordInvalid) { @update.call(actor: @admin, id: row.id, attributes: { effective_from: Date.current-1, lock_version: 0 }) }
    row.shift_snapshot=row.shift_snapshot.merge("start_minute"=>0)
    assert_not row.valid?
  end
  test "end update requires fresh version and closing allows next assignment" do
    row=create
    assert_raises(ActiveRecord::RecordInvalid) { @update.call(actor: @admin, id: row.id, attributes: { effective_to: Date.current }) }
    @update.call(actor: @admin, id: row.id, attributes: { effective_to: Date.current, lock_version: 0 })
    assert_raises(ActiveRecord::StaleObjectError) { @update.call(actor: @admin, id: row.id, attributes: { effective_to: Date.current+1, lock_version: 0 }) }
    assert create(effective_from: Date.current+1).persisted?
  end
  test "historical assignment cannot be deleted but future assignment can" do
    row=create(effective_to: Date.current)
    assert_raises(ActiveRecord::RecordInvalid) { @delete.call(actor: @admin, id: row.id, lock_version: 0) }
    future=create(effective_from: Date.current+1)
    @delete.call(actor: @admin, id: future.id, lock_version: 0)
    assert_not EmployeeShiftAssignment.exists?(future.id)
    assert EmployeeShiftAssignment.exists?(row.id)
  end
  test "inactive shift employee and dates before hire are rejected" do
    @shift.update!(active: false)
    assert_raises(ActiveRecord::RecordInvalid) { create }
    @shift.update!(active: true)
    assert_raises(ActiveRecord::RecordInvalid) { create(effective_from: @employee.hired_on-1) }
    @employee.update!(status: :inactive)
    assert_raises(ActiveRecord::RecordInvalid) { create }
  end
  test "MySQL composite FK rejects cross tenant employee and date bypass" do
    row=create
    company=Company.create!(code: "FOREIGN", name: "Foreign")
    foreign=make_employee(make_user(:employee, company: company))
    assert_raises(ActiveRecord::InvalidForeignKey) { EmployeeShiftAssignment.where(id: row.id).update_all(employee_id: foreign.id) } # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    assert_raises(ActiveRecord::StatementInvalid) { EmployeeShiftAssignment.where(id: row.id).update_all(effective_to: Date.current-1) } # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    assert_raises(ActiveRecord::RecordNotFound) { create(employee_id: foreign.id) }
    assert_raises(ActiveRecord::RecordNotFound) { @schedule.call(actor: @admin, employee_id: foreign.id) }
    foreign_shift = HrmAttendance::Application::Commands::CreateWorkShift.new.call(actor: make_user(:admin, company: company),
      attributes: { code: "FOREIGN", name: "Foreign shift", start_time: "08:00", end_time: "17:00" })
    assert_raises(ActiveRecord::InvalidForeignKey) { EmployeeShiftAssignment.where(id: row.id).update_all(work_shift_id: foreign_shift.id) } # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
  end
  test "employee sees own assignments only and revoked permission denies direct use case" do
    own=create
    another=make_employee
    create(employee_id: another.id)
    data=@workspace.call(actor: @employee.user)
    assert_equal([ own.id ], data[:rows].pluck(:id))
    assert_raises(ActiveRecord::RecordNotFound) { @workspace.call(actor: another.user, id: own.id) }
    @employee.user.user_permissions.create!(permission: Permission.find_by!(key: "shift_assignments.read"), granted: false)
    assert_raises(Pundit::NotAuthorizedError) { @workspace.call(actor: @employee.user) }
  end
  test "snapshot calculation remains unchanged after editing source shift" do
    row=create
    start=Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 8)
    attendance=@employee.attendances.create!(work_date: Date.current, checked_in_at: start, checked_out_at: start+9.hours)
    data=nil
    assert_no_difference [ "Attendance.count", "AuditLog.count", "OutboxEvent.count" ] do
      data=report
    end
    assert_equal 480, data[:rows].first[:result][:worked_minutes]
    assert_equal "/attendances/#{attendance.id}", data[:rows].first[:attendance_path]
    @shift.update!(unpaid_break_minutes: 120)
    assert_equal 480, report[:rows].first[:result][:worked_minutes]
    assert_equal 60, row.reload.shift_snapshot["unpaid_break_minutes"]
  end
  test "schedule hides attendance without read entitlement and never infers absence" do
    create
    assert_equal "not_recorded", report[:rows].first[:status]
    @admin.user_permissions.create!(permission: Permission.find_by!(key: "attendance.read_all"), granted: false)
    data=report
    assert_equal "restricted", data[:rows].first[:status]
    assert_nil data[:rows].first[:attendance_id]
  end
  test "unassigned day is explicit and overlap bypass fails closed as conflict" do
    assert_equal "unassigned", report[:rows].first[:status]
    row=create
    EmployeeShiftAssignment.insert_all!([ { company_id: row.company_id, employee_id: row.employee_id, work_shift_id: row.work_shift_id, # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
      effective_from: Date.current-1, shift_snapshot: row.shift_snapshot, created_at: Time.current, updated_at: Time.current } ])
    assert_equal "conflict", report[:rows].first[:status]
    assert_nil report[:rows].first[:result]
  end
  test "period is bounded and source employee ID is scoped and typed" do
    assert_equal 31, @schedule.call(actor: @admin, employee_id: @employee.id, from: Date.current.to_s, to: (Date.current+30).to_s)[:rows].length
    [ "bad", "2026-02-30", [ Date.current.to_s ] ].each do |from|
      assert_raises(HrmAttendance::Application::Queries::EmployeeShiftSchedule::InvalidPeriod) { @schedule.call(actor: @admin, from: from) }
    end
    assert_raises(HrmAttendance::Application::Queries::EmployeeShiftSchedule::InvalidPeriod) { @schedule.call(actor: @admin, from: Date.current.to_s, to: (Date.current+31).to_s) }
    assert_raises(ActiveRecord::RecordNotFound) { @schedule.call(actor: @employee.user, employee_id: make_employee.id) }
    assert_raises(ActiveRecord::RecordNotFound) { @schedule.call(actor: @admin, employee_id: ActionController::Parameters.new(x: 1)) }
  end
  test "shift and employee deletion cannot orphan scheduling history" do
    create
    assert_not @shift.destroy
    assert_not @employee.destroy
  end
  test "assigned night schedule keeps check in date and ends the following day" do
    @shift.update!(start_time: "22:00", end_time: "06:00", unpaid_break_minutes: 30)
    create
    start = Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 22)
    @employee.attendances.create!(work_date: Date.current, checked_in_at: start, checked_out_at: start + 8.hours)
    row = report[:rows].first
    assert_equal Date.current, row[:start].to_date
    assert_equal Date.current + 1, row[:finish].to_date
    assert_equal 450, row[:result][:worked_minutes]
  end

  test "malformed optional end date cannot silently become an open interval" do
    [ "bad", "2026-02-30", "2026-1-1", 123 ].each do |value|
      assert_raises(ActiveRecord::RecordInvalid) { create(effective_to: value) }
    end
    assert_equal 0, EmployeeShiftAssignment.count
  end
end
