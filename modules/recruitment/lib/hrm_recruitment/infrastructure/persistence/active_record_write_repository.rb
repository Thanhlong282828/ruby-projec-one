module HrmRecruitment
  module Infrastructure
    module Persistence
      class ActiveRecordWriteRepository < Domain::Repositories::WriteRepositoryInterface
        def build(attributes:) = ::Candidate.new(attributes)
        def save!(record:)
          record.save!
          record
        end
        def update!(record:, attributes:)
          record.update!(attributes)
          record
        end
      end
    end
  end
end
