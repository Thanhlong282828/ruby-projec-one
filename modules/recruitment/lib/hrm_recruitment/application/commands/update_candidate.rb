module HrmRecruitment
  module Application
    module Commands
      class UpdateCandidate < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface))
          @repository = repository
        end
        def call(actor:, record:, attributes:)
          authorize!(actor, record, :update?)
          @repository.update!(record: record, attributes: attributes)
        end
      end
    end
  end
end
