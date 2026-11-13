# typed: strict

module HrmTimeOff
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        extend T::Sig
        sig { override.params(actor: User).returns(Integer) }
        def count(actor:) = Pundit.policy_scope!(actor, ::LeaveRequest).count
        sig { override.params(actor: User, page: T.nilable(T.any(Integer, String)), recent: T::Boolean, status: T.nilable(String)).returns(T::Array[LeaveRequest]) }
        def list(actor:, page: 1, recent: false, status: nil)
          scope = Pundit.policy_scope!(actor, ::LeaveRequest).includes(:employee).order(created_at: :desc, id: :desc)
          scope = scope.where(status: status) if status
          recent ? scope.limit(5).to_a : Hrm::Pagination.call(scope, page).to_a
        end
        sig { override.params(actor: User, id: T.nilable(T.any(Integer, String))).returns(LeaveRequest) }
        def find!(actor:, id:) = Pundit.policy_scope!(actor, ::LeaveRequest).find(id)
        sig { override.params(actor: User).returns(T::Array[Employee]) }
        def employee_options(actor:) = Pundit.policy_scope!(actor, ::Employee).order(:full_name).to_a
        sig { override.params(employee: Employee, year: Integer, lock: T::Boolean).returns(T.any(Integer, BigDecimal)) }
        def used_days(employee:, year:, lock: false)
          scope = employee.leave_requests.approved.where(starts_on: Date.new(year)..Date.new(year, 12, 31))
          (lock ? scope.lock : scope).to_a.sum(&:days)
        end
        sig { override.params(actor: T.nilable(User), company_id: T.nilable(Integer)).returns(Integer) }
        def pending_count(actor: nil, company_id: nil)
          raise ArgumentError, "company_id is required for scheduler" unless actor || company_id
          scope = actor ? Pundit.policy_scope!(actor, ::LeaveRequest) : ::LeaveRequest.where(company_id: company_id)
          scope.pending.count
        end
        sig { override.params(id: Integer, company_id: Integer).returns(LeaveRequest) }
        def find_for_mail!(id:, company_id:) = ::LeaveRequest.where(company_id: company_id).find(id)
      end
    end
  end
end
