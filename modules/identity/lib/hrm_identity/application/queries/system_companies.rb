module HrmIdentity
  module Application
    module Queries
      class SystemCompanies < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::TenantReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, before: nil)
          require_actor!(actor)
          Pundit.authorize(actor, ::Company, :index?, policy_class: ::SystemCompanyPolicy)
          @repository.companies(actor:, before:)
        end
      end
    end
  end
end
