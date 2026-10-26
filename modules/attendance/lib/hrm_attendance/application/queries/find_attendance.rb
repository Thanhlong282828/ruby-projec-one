module HrmAttendance
  module Application
    module Queries
      class FindAttendance < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @repository = repository
        end
        def call(actor:, id:)
          require_actor!(actor)
          @repository.find!(actor: actor, id: id)
        end
      end
    end
  end
end
