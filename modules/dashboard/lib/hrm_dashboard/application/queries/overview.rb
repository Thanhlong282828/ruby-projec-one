module HrmDashboard
  module Application
    module Queries
      class Overview < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, period: nil)
          require_actor!(actor)
          raise Pundit::NotAuthorizedError unless actor.allowed?("dashboard.view")
          @repository.snapshot(actor: actor, period: Hrm::ListFilters.month(period) || Date.current.beginning_of_month)
        end
      end
    end
  end
end
