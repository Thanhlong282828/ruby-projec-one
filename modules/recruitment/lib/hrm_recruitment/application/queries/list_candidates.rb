module HrmRecruitment
  module Application
    module Queries
      class ListCandidates < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface))
          @repository = repository
        end
        def call(actor:, page: 1)
          authorize!(actor, ::Candidate, :index?)
          @repository.list(actor: actor, page: page)
        end
      end
    end
  end
end
