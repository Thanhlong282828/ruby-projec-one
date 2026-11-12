module HrmPayroll
  module Domain
    module Repositories
      class ExportWriteRepositoryInterface
        def create!(actor:, pay_run_id:)
          raise NotImplementedError
        end
        def download!(actor:, id:)
          raise NotImplementedError
        end
      end
    end
  end
end
