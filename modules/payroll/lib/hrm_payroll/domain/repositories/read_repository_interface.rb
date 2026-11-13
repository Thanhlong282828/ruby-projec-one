# typed: strict

module HrmPayroll
  module Domain
    module Repositories
      class ReadRepositoryInterface
        extend T::Sig
        sig { params(actor: User, run: PayRun).returns(HrmPayroll::Domain::ReconciliationResult) }
        def reconciliation(actor:, run:) = raise(NotImplementedError)
        sig { params(actor: User, page: T.nilable(T.any(Integer, String)), status: T.nilable(String), period: T.nilable(Date), recent: T::Boolean).returns(T::Array[PayRun]) }
        def list(actor:, page: 1, status: nil, period: nil, recent: false)
          raise NotImplementedError, "HrmPayroll::ReadRepositoryInterface##list"
        end
        sig { params(actor: User, status: T.nilable(String), period: T.nilable(Date)).returns(Integer) }
        def count(actor:, status: nil, period: nil) = raise(NotImplementedError)
        sig { params(actor: User, id: T.nilable(T.any(Integer, String))).returns(PayRun) }
        def find!(actor:, id:)
          raise NotImplementedError, "HrmPayroll::ReadRepositoryInterface##find!"
        end
        sig { params(actor: User, run: PayRun).returns(T::Array[Payslip]) }
        def payslips(actor:, run:)
          raise NotImplementedError, "HrmPayroll::ReadRepositoryInterface##payslips"
        end
      end
    end
  end
end
