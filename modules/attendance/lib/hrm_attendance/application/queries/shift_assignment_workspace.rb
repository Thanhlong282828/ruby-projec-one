module HrmAttendance
  module Application
    module Queries
      class ShiftAssignmentWorkspace < Hrm::UseCase
        def initialize(read: Hrm::Container.resolve(Domain::Repositories::ScheduleReadRepositoryInterface))
          super()
          (@read=read)
        end
        def call(actor:, id: nil, form: false, page: 1)
          require_actor!(actor)
          if id
            authorize!(actor, ::EmployeeShiftAssignment, :index?)
            record=@read.find!(actor: actor, id: id)
            authorize!(actor, record, :update?) if form
          elsif form
            record=::EmployeeShiftAssignment.new(company_id: actor.company_id, effective_from: Date.current)
            authorize!(actor, record, :create?)
          else
            authorize!(actor, ::EmployeeShiftAssignment, :index?)
            return { rows: @read.list(actor: actor, page: page).map { |row| describe(actor, row) } }
          end
          { record: record, row: record.persisted? ? describe(actor, record) : nil, options: form && !record.persisted? ? @read.options(actor: actor, form: true) : { employees: [], shifts: [] } }
        end
        private
        def clock(minute) = format("%02d:%02d", minute / 60, minute % 60)
        def describe(actor, record)
          record.public_attributes.symbolize_keys.merge(employee_name: record.employee.full_name,
            employee_path: Pundit.policy!(actor, record.employee).show? ? "/employees/#{record.employee_id}" : nil,
            start_time: clock(record.shift_snapshot.fetch("start_minute")),
            end_time: clock(record.shift_snapshot.fetch("end_minute")),
            crosses_midnight: record.shift_snapshot.fetch("end_minute") < record.shift_snapshot.fetch("start_minute"),
            shift_code: record.shift_snapshot.fetch("code"), shift_name: record.shift_snapshot.fetch("name"),
            shift_path: Pundit.policy!(actor, record.work_shift).show? ? "/work_shifts/#{record.work_shift_id}" : nil)
        end
      end
    end
  end
end
