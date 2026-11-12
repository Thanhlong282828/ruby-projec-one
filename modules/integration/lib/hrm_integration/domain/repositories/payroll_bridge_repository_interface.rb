module HrmIntegration
  module Domain
    module Repositories
      class PayrollBridgeRepositoryInterface
        def enqueue!(actor:, export_id:, connection_id:, target_key:)
          raise NotImplementedError
        end
      end
    end
  end
end
