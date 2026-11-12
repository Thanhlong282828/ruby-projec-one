module HrmIdentity
  module Application
    module Commands
      class CreateSystemCompany < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::TenantWriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, attributes:)
          require_actor!(actor)
          Pundit.authorize(actor, ::Company, :create?, policy_class: ::SystemCompanyPolicy)
          @repository.create_company!(actor:, attributes:)
        end
      end
    end
  end
end
