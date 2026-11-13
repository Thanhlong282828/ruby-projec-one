# typed: strict

module HrmTimeOff
  module Infrastructure
    module Persistence
      class ActiveRecordWriteRepository < Domain::Repositories::WriteRepositoryInterface
        extend T::Sig
        sig { override.params(employee: Employee, attributes: T::Hash[Symbol, Object]).returns(LeaveRequest) }
        def build(employee:, attributes:) = employee.leave_requests.new(attributes.merge(company_id: employee.company_id))
        sig { override.params(employee: Employee, attributes: T::Hash[Symbol, Object]).returns(T.nilable(LeaveRequest)) }
        def create!(employee:, attributes:) = employee.with_lock { employee.leave_requests.create!(attributes) }
        sig { override.type_parameters(:Result).params(request: LeaveRequest, block: T.proc.returns(T.type_parameter(:Result))).returns(T.nilable(T.type_parameter(:Result))) }
        def with_review_lock(request:, &block)
          employee = T.must(request.employee) # Persisted requests have a non-null employee FK.
          employee.with_lock do
            request.lock!
            raise ActiveRecord::StaleObjectError.new(request, "review") unless request.employee_id == employee.id
            request.association(:employee).target = employee
            ActiveRecord::Base.uncached { yield }
          end
        end
        sig { override.params(request: LeaveRequest, reviewer: User, decision: String).returns(LeaveRequest) }
        def review!(request:, reviewer:, decision:)
          request.update!(status: decision, reviewer: reviewer, reviewed_at: Time.current)
          request
        end
      end
    end
  end
end
