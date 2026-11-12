module HrmIdentity
  module Application
    module Commands
      class AssignCompanyMembership < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::TenantWriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, company_id:, principal_id:, role:)
          require_actor!(actor)
          Pundit.authorize(actor, ::Company, :create?, policy_class: ::SystemCompanyPolicy)
          @repository.assign_membership!(actor:, company_id:, principal_id:, role:)
        end
      end
    end
  end
end
