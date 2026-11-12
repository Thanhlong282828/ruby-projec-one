module HrmOrganization
  module Application
    module Queries
      class Structure < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          super()
          (@repository = repository)
        end
        def call(actor:, view:, on: Date.current)
          authorize!(actor, ::OrganizationUnit, :index?)
          if view == :tree
            @repository.tree(actor: actor)
          elsif view == :headcount
            authorize!(actor, ::JobPosition, :index?)
            authorize!(actor, ::EmployeeAssignment, :index?)
            @repository.headcount(actor: actor, on: on)
          else
            raise ArgumentError, "Unknown structure view"
          end
        end
      end
    end
  end
end
