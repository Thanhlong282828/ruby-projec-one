module HrmIdentity
  module Application
    module Queries
      class CompanyMemberships < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::TenantReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:)
          @repository.memberships(actor:)
        end
      end
    end
  end
end
