module HrmIntegration
  module Domain
    module Repositories
      class OutboundReadRepositoryInterface
        def payroll_workspace(actor:, export_id:)
          raise NotImplementedError
        end
        def workspace(actor:, page: 1, status: nil)
          raise NotImplementedError
        end
        def find!(actor:, id:, payload: false)
          raise NotImplementedError
        end
      end
    end
  end
end
