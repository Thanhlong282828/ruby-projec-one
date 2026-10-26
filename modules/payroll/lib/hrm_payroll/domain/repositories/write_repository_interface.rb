module HrmPayroll
  module Domain
    module Repositories
      class WriteRepositoryInterface
        def transaction(&block)
          raise NotImplementedError, "HrmPayroll::WriteRepositoryInterface##transaction"
        end
        def create_run!(period:, actor:)
          raise NotImplementedError, "HrmPayroll::WriteRepositoryInterface##create_run!"
        end
        def create_payslip!(run:, employee:)
          raise NotImplementedError, "HrmPayroll::WriteRepositoryInterface##create_payslip!"
        end
        def finalize!(run:, &block)
          raise NotImplementedError, "HrmPayroll::WriteRepositoryInterface##finalize!"
        end
        def has_payslips?(run:)
          raise NotImplementedError, "HrmPayroll::WriteRepositoryInterface##has_payslips?"
        end
      end
    end
  end
end
