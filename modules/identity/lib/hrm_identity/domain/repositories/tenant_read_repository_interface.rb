module HrmIdentity
  module Domain
    module Repositories
      class TenantReadRepositoryInterface
        def memberships(actor:)
          raise NotImplementedError
        end
        def companies(actor:, before: nil)
          raise NotImplementedError
        end
        def company(actor:, id:)
          raise NotImplementedError
        end
      end
    end
  end
end
