module HrmAttendance
  module Application
    module Queries
      class PreviewWorkShift < Hrm::UseCase
        def initialize(shifts: Hrm::Container.resolve(Domain::Repositories::ShiftReadRepositoryInterface), attendances: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface), calculator: Domain::Services::AttendanceCalculator.new)
          super()
          @shifts, @attendances, @calculator = shifts, attendances, calculator
        end
        def call(actor:, id:, attendance_id:)
          require_actor!(actor)
          shift = @shifts.find!(actor: actor, id: id)
          authorize!(actor, shift, :show?)
          authorize!(actor, ::Attendance, :index?)
          source_id = (attendance_id.is_a?(String) || attendance_id.is_a?(Integer)) ? Integer(attendance_id.to_s, exception: false) : nil
          raise ActiveRecord::RecordNotFound unless source_id && source_id.positive?
          attendance = @attendances.find!(actor: actor, id: source_id)
          day = attendance.work_date
          start = Time.zone.local(day.year, day.month, day.day, shift.start_minute / 60, shift.start_minute % 60)
          end_day = shift.crosses_midnight? ? day + 1 : day
          finish = Time.zone.local(end_day.year, end_day.month, end_day.day, shift.end_minute / 60, shift.end_minute % 60)
          result = @calculator.call(scheduled_start: start, scheduled_end: finish,
            check_in: attendance.checked_in_at, check_out: attendance.checked_out_at,
            break_minutes: shift.unpaid_break_minutes, grace_in_minutes: shift.grace_in_minutes,
            grace_out_minutes: shift.grace_out_minutes, overtime_threshold_minutes: shift.overtime_threshold_minutes)
          { shift: shift.public_attributes, attendance_id: attendance.id, work_date: day,
            scheduled_start: start, scheduled_end: finish, result: result,
            attendance_path: "/attendances/report?from=#{day.iso8601}&to=#{day.iso8601}", preview_only: true }
        end
      end
    end
  end
end
