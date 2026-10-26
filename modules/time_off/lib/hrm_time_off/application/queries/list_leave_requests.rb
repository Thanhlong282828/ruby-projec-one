module HrmTimeOff
  module Application
    module Queries
      class ListLeaveRequests < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @repository = repository
        end
        def call(actor:, page: 1, recent: false)
          authorize!(actor, ::LeaveRequest, :index?)
          @repository.list(actor: actor, page: page, recent: recent)
        end
      end
    end
  end
end
