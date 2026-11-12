module HrmIdentity
  module Application
    module Commands
      class SwitchCompany < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::TenantWriteRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, credential:, membership_id:)
          require_actor!(actor)
          @repository.switch!(actor:, credential:, membership_id:)
        end
      end
    end
  end
end
