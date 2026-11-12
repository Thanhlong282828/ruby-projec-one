module HrmOrganization
  module Application
    module Queries
      class Branches < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          @repository = repository
        end
        def call(actor:, q: nil, status: nil, after: nil)
          authorize!(actor, ::OrganizationUnit, :index?)
          @repository.branches(actor: actor, q: q, status: status, after: after)
        end
      end
    end
  end
end
