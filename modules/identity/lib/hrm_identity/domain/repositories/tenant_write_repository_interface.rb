module HrmIdentity
  module Domain
    module Repositories
      class TenantWriteRepositoryInterface
        def grant_system_owner!(email:)
          raise NotImplementedError
        end
        def create_company!(actor:, attributes:)
          raise NotImplementedError
        end
        def update_company!(actor:, id:, attributes:, lock_version:)
          raise NotImplementedError
        end
        def assign_membership!(actor:, company_id:, principal_id:, role:)
          raise NotImplementedError
        end
        def switch!(actor:, credential:, membership_id:)
          raise NotImplementedError
        end
      end
    end
  end
end
