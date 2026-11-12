module HrmAttendance
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        def list(actor:, page: 1) = Hrm::Pagination.call(Pundit.policy_scope!(actor, ::Attendance).includes(:employee).order(work_date: :desc), page).to_a
        def period(actor:, from:, to:, page: 1)
          scope = Pundit.policy_scope!(actor, ::Attendance).where(work_date: from..to)
          # Fixed SQL expressions, never interpolate request values into SQL.
          counts = scope.pick(Arel.sql("COUNT(*)"),
            Arel.sql("SUM(CASE WHEN checked_out_at IS NULL THEN 1 ELSE 0 END)"),
            Arel.sql("SUM(CASE WHEN checked_out_at IS NOT NULL THEN TIMESTAMPDIFF(SECOND, checked_in_at, checked_out_at) ELSE 0 END)"),
            Arel.sql("SUM(CASE WHEN TIMESTAMPDIFF(SECOND, checked_in_at, checked_out_at) > 57600 THEN 1 ELSE 0 END)"))
          { records: Hrm::Pagination.call(scope.includes(:employee).order(work_date: :desc, id: :desc), page).to_a,
            summary: { total: counts[0].to_i, open: counts[1].to_i,
              elapsed_seconds: counts[2].to_i, excessive: counts[3].to_i } }
        end
        def find!(actor:, id:) = Pundit.policy_scope!(actor, ::Attendance).includes(:employee).find(id)
      end
    end
  end
end
