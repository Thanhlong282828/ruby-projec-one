module HrmWorkforce
  module Application
    module Queries
      class CurrentEmployee < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @repository = repository
        end
        def call(actor:)
          require_actor!(actor)
          @repository.employee_for_user!(user: actor)
        rescue ActiveRecord::RecordNotFound
          nil
        end
      end
    end
  end
end
