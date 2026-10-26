module HrmDashboard
  module Application
    module Queries
      class Overview < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @repository = repository
        end
        def call(actor:)
          require_actor!(actor)
          @repository.snapshot(actor: actor)
        end
      end
    end
  end
end
