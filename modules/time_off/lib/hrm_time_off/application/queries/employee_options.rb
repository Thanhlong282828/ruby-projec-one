module HrmTimeOff
  module Application
    module Queries
      class EmployeeOptions < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @repository = repository
        end
        def call(actor:)
          require_actor!(actor)
          raise Pundit::NotAuthorizedError unless actor.allowed?("leave.submit") || actor.allowed?("leave.submit_for_others")
          @repository.employee_options(actor: actor)
        end
      end
    end
  end
end
