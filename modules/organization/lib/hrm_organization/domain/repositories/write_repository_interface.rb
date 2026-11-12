module HrmOrganization
  module Domain
    module Repositories
      class WriteRepositoryInterface
        def build(resource:, company_id:, attributes:) = raise(NotImplementedError)
        def within_company_lock(company_id:, &block) = raise(NotImplementedError)
        def save!(record:, attributes: nil) = raise(NotImplementedError)
        def destroy!(record:) = raise(NotImplementedError)
      end
    end
  end
end
