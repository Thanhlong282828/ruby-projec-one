module HrmWorkforce
  module Application
    module Queries
      class EmployeeFormOptions < Hrm::UseCase
        def initialize(workforce: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface), identity: Hrm::Container.resolve(HrmIdentity::Domain::Repositories::ReadRepositoryInterface))
          @workforce, @identity = workforce, identity
        end
        def call(actor:)
          require_actor!(actor)
          raise Pundit::NotAuthorizedError unless actor.allowed?("employees.create") || actor.allowed?("employees.update")
          @workforce.form_options(actor: actor).merge(users: @identity.user_options(actor: actor))
        end
      end
    end
  end
end
