# typed: strict

module HrmTimeOff
  module Domain
    module Repositories
      class WriteRepositoryInterface
        extend T::Sig
        sig { overridable.params(employee: Employee, attributes: T::Hash[Symbol, Object]).returns(LeaveRequest) }
        def build(employee:, attributes:)
          raise NotImplementedError, "HrmTimeOff::WriteRepositoryInterface##build"
        end
        sig { overridable.params(employee: Employee, attributes: T::Hash[Symbol, Object]).returns(T.nilable(LeaveRequest)) }
        def create!(employee:, attributes:)
          raise NotImplementedError, "HrmTimeOff::WriteRepositoryInterface##create!"
        end
        sig { overridable.type_parameters(:Result).params(request: LeaveRequest, block: T.proc.returns(T.type_parameter(:Result))).returns(T.nilable(T.type_parameter(:Result))) }
        def with_review_lock(request:, &block)
          raise NotImplementedError, "HrmTimeOff::WriteRepositoryInterface##with_review_lock"
        end
        sig { overridable.params(request: LeaveRequest, reviewer: User, decision: String).returns(LeaveRequest) }
        def review!(request:, reviewer:, decision:)
          raise NotImplementedError, "HrmTimeOff::WriteRepositoryInterface##review!"
        end
      end
    end
  end
end
