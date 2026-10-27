module HrmAttendance
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        def list(actor:, page: 1) = Hrm::Pagination.call(Pundit.policy_scope!(actor, ::Attendance).includes(:employee).order(work_date: :desc), page).to_a
        def find!(actor:, id:) = Pundit.policy_scope!(actor, ::Attendance).find(id)
      end
    end
  end
end
