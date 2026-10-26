module HrmPayroll
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def list(actor:, page: 1)
          raise NotImplementedError, "HrmPayroll::ReadRepositoryInterface##list"
        end
        def find!(actor:, id:)
          raise NotImplementedError, "HrmPayroll::ReadRepositoryInterface##find!"
        end
        def payslips(run:)
          raise NotImplementedError, "HrmPayroll::ReadRepositoryInterface##payslips"
        end
      end
    end
  end
end
