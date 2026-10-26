module HrmIdentity
  module Application
    module Queries
      class FindActiveUser
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @repository = repository
        end
        def call(id:) = @repository.active_user(id: id)
      end
    end
  end
end
