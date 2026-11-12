module HrmAttendance
  module Infrastructure
    module Persistence
      class ActiveRecordShiftReadRepository < Domain::Repositories::ShiftReadRepositoryInterface
        def list(actor:, page: 1) = Hrm::Pagination.call(Pundit.policy_scope!(actor, ::WorkShift).order(:code, :id), page).to_a
        def find!(actor:, id:) = Pundit.policy_scope!(actor, ::WorkShift).find(id)
        def attendance_options(actor:)
          Pundit.policy_scope!(actor, ::Attendance).includes(:employee).order(work_date: :desc, id: :desc).limit(25).map do |row|
            [ "#{row.employee.full_name} — #{row.work_date}", row.id ]
          end
        end
      end
    end
  end
end
