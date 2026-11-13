# typed: strict

module HrmTimeOff
  module Domain
    module Repositories
      class ReadRepositoryInterface
        extend T::Sig
        sig { overridable.params(actor: User).returns(Integer) }
        def count(actor:)
          raise NotImplementedError
        end
        sig { overridable.params(actor: User, page: T.nilable(T.any(Integer, String)), recent: T::Boolean, status: T.nilable(String)).returns(T::Array[LeaveRequest]) }
        def list(actor:, page: 1, recent: false, status: nil)
          raise NotImplementedError, "HrmTimeOff::ReadRepositoryInterface##list"
        end
        sig { overridable.params(actor: User, id: T.nilable(T.any(Integer, String))).returns(LeaveRequest) }
        def find!(actor:, id:)
          raise NotImplementedError, "HrmTimeOff::ReadRepositoryInterface##find!"
        end
        sig { overridable.params(actor: User).returns(T::Array[Employee]) }
        def employee_options(actor:)
          raise NotImplementedError, "HrmTimeOff::ReadRepositoryInterface##employee_options"
        end
        sig { overridable.params(employee: Employee, year: Integer, lock: T::Boolean).returns(T.any(Integer, BigDecimal)) }
        def used_days(employee:, year:, lock: false)
          raise NotImplementedError, "HrmTimeOff::ReadRepositoryInterface##used_days"
        end
        sig { overridable.params(actor: T.nilable(User), company_id: T.nilable(Integer)).returns(Integer) }
        def pending_count(actor: nil, company_id: nil)
          raise NotImplementedError, "HrmTimeOff::ReadRepositoryInterface##pending_count"
        end
        sig { overridable.params(id: Integer, company_id: Integer).returns(LeaveRequest) }
        def find_for_mail!(id:, company_id:)
          raise NotImplementedError, "HrmTimeOff::ReadRepositoryInterface##find_for_mail!"
        end
      end
    end
  end
end
