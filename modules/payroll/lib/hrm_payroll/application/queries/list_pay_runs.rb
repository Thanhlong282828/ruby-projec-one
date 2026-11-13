module HrmPayroll
  module Application
    module Queries
      class ListPayRuns < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, page: 1, status: nil, period: nil)
          authorize!(actor, ::PayRun, :index?)
          @repository.list(actor: actor, page: page, status: Hrm::ListFilters.choice(status, allowed: %w[draft finalized]), period: Hrm::ListFilters.month(period))
        end
      end
    end
  end
end
