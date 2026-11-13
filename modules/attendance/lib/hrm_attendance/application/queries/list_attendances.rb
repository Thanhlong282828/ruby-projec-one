module HrmAttendance
  module Application
    module Queries
      class ListAttendances < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, page: 1, status: nil)
          authorize!(actor, ::Attendance, :index?)
          @repository.list(actor: actor, page: page, status: Hrm::ListFilters.choice(status, allowed: %w[open closed]))
        end
      end
    end
  end
end
