module HrmTimeOff
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        def list(actor:, page: 1, recent: false)
          scope = Pundit.policy_scope!(actor, ::LeaveRequest).includes(:employee).order(created_at: :desc)
          recent ? scope.limit(5).to_a : Hrm::Pagination.call(scope, page).to_a
        end
        def find!(actor:, id:) = Pundit.policy_scope!(actor, ::LeaveRequest).find(id)
        def employee_options(actor:) = Pundit.policy_scope!(actor, ::Employee).order(:full_name).to_a
        def used_days(employee:, year:) = employee.leave_requests.approved.where(starts_on: Date.new(year)..Date.new(year, 12, 31)).sum { |leave| leave.days }
        def pending_count(actor: nil)
          scope = actor ? Pundit.policy_scope!(actor, ::LeaveRequest) : ::LeaveRequest
          scope.pending.count
        end
        def find_for_mail!(id:) = ::LeaveRequest.find(id)
      end
    end
  end
end
