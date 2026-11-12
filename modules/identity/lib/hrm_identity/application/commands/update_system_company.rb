module HrmIdentity
  module Application
    module Commands
      class UpdateSystemCompany < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::TenantWriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, id:, attributes:, lock_version:)
          require_actor!(actor)
          Pundit.authorize(actor, ::Company, :create?, policy_class: ::SystemCompanyPolicy)
          @repository.update_company!(actor:, id:, attributes:, lock_version:)
        end
      end
    end
  end
end
