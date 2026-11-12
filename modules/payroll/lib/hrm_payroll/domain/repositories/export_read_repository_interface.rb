module HrmPayroll
  module Domain
    module Repositories
      class ExportReadRepositoryInterface
        def workspace(actor:, before: nil, period: nil)
          raise NotImplementedError
        end
        def find!(actor:, id:)
          raise NotImplementedError
        end
      end
    end
  end
end
