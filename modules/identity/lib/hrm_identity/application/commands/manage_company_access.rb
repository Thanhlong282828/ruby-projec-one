module HrmIdentity
  module Application
    module Commands
      class ManageCompanyAccess < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::AdministrationRepositoryInterface)) = (@repository = repository)
        def call(actor:, area:, attributes:, id: nil)
          require_actor!(actor)
          case area
          when :company then @repository.update_company!(actor: actor, attributes: attributes)
          when :accounts then @repository.update_account!(actor: actor, id: id, attributes: attributes)
          when :roles then @repository.update_role!(actor: actor, id: id, attributes: attributes)
          else raise ArgumentError, "Unknown administration area"
          end
        end
      end
    end
  end
end
