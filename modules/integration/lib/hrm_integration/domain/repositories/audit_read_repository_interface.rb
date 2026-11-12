module HrmIntegration
  module Domain
    module Repositories
      class AuditReadRepositoryInterface
        def workspace(actor:, filters:)
          raise NotImplementedError
        end
      end
    end
  end
end
