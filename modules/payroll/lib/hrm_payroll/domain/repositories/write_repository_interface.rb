# typed: strict

module HrmPayroll
  module Domain
    module Repositories
      class WriteRepositoryInterface
        extend T::Sig
        sig { type_parameters(:Result).params(actor: User, block: T.proc.returns(T.type_parameter(:Result))).returns(T.nilable(T.type_parameter(:Result))) }
        def transaction(actor:, &block)
          raise NotImplementedError, "HrmPayroll::WriteRepositoryInterface##transaction"
        end
        sig { params(period: T.nilable(T.any(Date, String)), actor: User).returns(PayRun) }
        def create_run!(period:, actor:)
          raise NotImplementedError, "HrmPayroll::WriteRepositoryInterface##create_run!"
        end
        sig { params(run: PayRun, employee: Employee).returns(Payslip) }
        def create_payslip!(run:, employee:)
          raise NotImplementedError, "HrmPayroll::WriteRepositoryInterface##create_payslip!"
        end
        sig { params(run: PayRun, actor: User, block: T.proc.params(run: PayRun).void).returns(PayRun) }
        def finalize!(run:, actor:, &block)
          raise NotImplementedError, "HrmPayroll::WriteRepositoryInterface##finalize!"
        end
        sig { params(run: PayRun).returns(T::Boolean) }
        def has_payslips?(run:)
          raise NotImplementedError, "HrmPayroll::WriteRepositoryInterface##has_payslips?"
        end
      end
    end
  end
end
