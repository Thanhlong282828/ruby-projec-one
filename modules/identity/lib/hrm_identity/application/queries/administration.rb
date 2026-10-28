module HrmIdentity
  module Application
    module Queries
      class Administration < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::AdministrationRepositoryInterface)) = (@repository = repository)
        def call(actor:, area:, id: nil)
          require_actor!(actor)
          @repository.snapshot(actor: actor, area: area, id: id)
        end
      end
    end
  end
end
