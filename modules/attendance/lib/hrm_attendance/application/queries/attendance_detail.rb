module HrmAttendance
  module Application
    module Queries
      class AttendanceDetail < Hrm::UseCase
        def initialize(read: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          (@read=read)
        end
        def call(actor:, id:)
          authorize!(actor, ::Attendance, :index?)
          row=@read.find!(actor: actor, id: id)
          { employee_name: row.employee.full_name, work_date: row.work_date, checked_in_at: row.checked_in_at, checked_out_at: row.checked_out_at }
        end
      end
    end
  end
end
