module HrmIdentity
  module Application
    module Queries
      class SystemCompany < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::TenantReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:)
          require_actor!(actor)
          Pundit.authorize(actor, ::Company, :index?, policy_class: ::SystemCompanyPolicy)
          @repository.company(actor:, id:)
        end
      end
    end
  end
end
