module HrmAttendance
  module Domain
    module Services
      class AttendanceCalculator
        # Pure calculation: no database, authorization, assignment or payroll writes.
        def call(scheduled_start:, scheduled_end:, check_in:, check_out:, break_minutes: 0,
          grace_in_minutes: 0, grace_out_minutes: 0, overtime_threshold_minutes: 0)
          raise ArgumentError, "Invalid schedule" unless scheduled_end > scheduled_start
          rules = [ break_minutes, grace_in_minutes, grace_out_minutes, overtime_threshold_minutes ]
          raise ArgumentError, "Invalid minute rules" unless rules.all? { |n| n.is_a?(Integer) && n >= 0 }
          scheduled = minutes(scheduled_end - scheduled_start)
          raise ArgumentError, "Break exceeds shift" unless break_minutes < scheduled
          result = { scheduled_minutes: scheduled, planned_work_minutes: scheduled - break_minutes,
            worked_minutes: 0, late_minutes: 0, early_minutes: 0, outside_shift_minutes: 0, status: "incomplete" }
          return result if check_in.nil? || check_out.nil?
          raise ArgumentError, "Checkout before checkin" if check_out < check_in
          late = [ minutes(check_in - scheduled_start) - grace_in_minutes, 0 ].max
          early = [ minutes(scheduled_end - check_out) - grace_out_minutes, 0 ].max
          result.merge(worked_minutes: [ minutes(check_out - check_in) - break_minutes, 0 ].max,
            late_minutes: late, early_minutes: early,
            outside_shift_minutes: [ minutes(check_out - scheduled_end) - overtime_threshold_minutes, 0 ].max,
            status: late > 0 && early > 0 ? "late_and_early" : (late > 0 ? "late" : (early > 0 ? "early_leave" : "present")))
        end
        private
        def minutes(seconds) = (seconds / 60).to_i
      end
    end
  end
end
