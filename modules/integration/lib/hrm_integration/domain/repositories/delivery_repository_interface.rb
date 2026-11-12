module HrmIntegration
  module Domain
    module Repositories
      class DeliveryRepositoryInterface
        def due_ids
          raise NotImplementedError
        end
        def deliver!(id:)
          raise NotImplementedError
        end
      end
    end
  end
end
