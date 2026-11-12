module HrmAttendance
  module Application
    module Queries
      class EmployeeShiftSchedule < Hrm::UseCase
        class InvalidPeriod < ArgumentError; end
        def initialize(read: Hrm::Container.resolve(Domain::Repositories::ScheduleReadRepositoryInterface), calculator: Domain::Services::AttendanceCalculator.new)
          super()
          @read, @calculator=read, calculator
        end
        def call(actor:, employee_id: nil, from: nil, to: nil)
          authorize!(actor, ::EmployeeShiftAssignment, :index?)
          first, last=parse_date(from, Date.current), parse_date(to, Date.current+6)
          raise InvalidPeriod, "Chọn từ 1 đến 31 ngày." unless (0..30).cover?((last-first).to_i)
          options=@read.options(actor: actor)
          return { from: first, to: last, employee: nil, options: options, rows: [], preview_only: true } if employee_id.nil? || employee_id==""
          employee=@read.employee!(actor: actor, id: employee_id)
          data=@read.period(actor: actor, employee: employee, from: first, to: last)
          can_read=actor.allowed?("attendance.read_all") || (actor.allowed?("attendance.read") && employee.user_id==actor.id)
          rows=(first..last).map do |day|
            assignments=data[:assignments].select { |a| a.effective_from<=day && (a.effective_to.nil? || a.effective_to>=day) }
            attendance=can_read ? data[:attendances][day] : nil
            row={ date: day, attendance_id: attendance&.id, attendance_path: attendance && "/attendances/#{attendance.id}", result: nil }
            next row.merge(status: "conflict") if assignments.size>1
            assignment=assignments.first
            next row.merge(status: "unassigned") unless assignment
            snapshot=assignment.shift_snapshot
            start=at(day, snapshot.fetch("start_minute"))
            finish=at(snapshot.fetch("end_minute")<snapshot.fetch("start_minute") ? day+1 : day, snapshot.fetch("end_minute"))
            result=attendance && @calculator.call(scheduled_start: start, scheduled_end: finish, check_in: attendance.checked_in_at, check_out: attendance.checked_out_at,
              break_minutes: snapshot.fetch("unpaid_break_minutes"), grace_in_minutes: snapshot.fetch("grace_in_minutes"), grace_out_minutes: snapshot.fetch("grace_out_minutes"), overtime_threshold_minutes: snapshot.fetch("overtime_threshold_minutes"))
            row.merge(status: !can_read ? "restricted" : (result ? result[:status] : "not_recorded"), result: result,
              shift_code: snapshot.fetch("code"), start: start, finish: finish, assignment_path: "/shift_assignments/#{assignment.id}")
          end
          { from: first, to: last, employee: { id: employee.id, name: employee.full_name }, options: options, rows: rows, preview_only: true }
        end
        private
        def at(day, minute) = Time.zone.local(day.year, day.month, day.day, minute/60, minute%60)
        def parse_date(value, fallback)
          return fallback if value.nil? || value==""
          raise InvalidPeriod, "Ngày phải có dạng YYYY-MM-DD." unless value.is_a?(String) && /\A\d{4}-\d{2}-\d{2}\z/.match?(value)
          Date.iso8601(value)
        rescue Date::Error
          raise InvalidPeriod, "Ngày không hợp lệ."
        end
      end
    end
  end
end
