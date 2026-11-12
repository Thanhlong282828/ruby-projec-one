require "test_helper"
class AttendanceCalculatorTest < ActiveSupport::TestCase
  def setup
    super
    @calculator = HrmAttendance::Domain::Services::AttendanceCalculator.new
    @start = Time.zone.local(2026, 11, 11, 8)
    @finish = @start + 9.hours
  end
  def calculate(**options)
    @calculator.call(**{ scheduled_start: @start, scheduled_end: @finish,
      check_in: @start, check_out: @finish, break_minutes: 60 }.merge(options))
  end
  test "standard day subtracts unpaid break and applies grace to both ends" do
    data = calculate(check_in: @start + 5.minutes, check_out: @finish - 5.minutes, grace_in_minutes: 5, grace_out_minutes: 5)
    assert_equal 480, data[:planned_work_minutes]
    assert_equal 470, data[:worked_minutes]
    assert_equal "present", data[:status]
  end
  test "late and early are residual minutes after grace" do
    data = calculate(check_in: @start + 12.minutes, check_out: @finish - 9.minutes, grace_in_minutes: 5, grace_out_minutes: 5)
    assert_equal 7, data[:late_minutes]
    assert_equal 4, data[:early_minutes]
    assert_equal "late_and_early", data[:status]
  end
  test "outside shift minutes are not approved overtime and threshold boundary is zero" do
    assert_equal 0, calculate(check_out: @finish + 30.minutes, overtime_threshold_minutes: 30)[:outside_shift_minutes]
    assert_equal 10, calculate(check_out: @finish + 40.minutes, overtime_threshold_minutes: 30)[:outside_shift_minutes]
  end
  test "short sessions cannot produce negative net time" do
    assert_equal 0, calculate(check_out: @start + 10.minutes)[:worked_minutes]
  end
  test "missing check in or check out returns incomplete" do
    assert_equal "incomplete", calculate(check_in: nil)[:status]
    assert_equal 0, calculate(check_out: nil)[:worked_minutes]
  end
  test "invalid schedule backwards attendance and negative rules raise" do
    assert_raises(ArgumentError) { calculate(scheduled_end: @start) }
    assert_raises(ArgumentError) { calculate(check_out: @start - 1.minute) }
    assert_raises(ArgumentError) { calculate(break_minutes: -1) }
    assert_raises(ArgumentError) { calculate(break_minutes: 540) }
  end
end
