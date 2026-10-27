module HrmRecruitment
  module Domain
    module Repositories
      class WriteRepositoryInterface
        def build(attributes:)
          raise NotImplementedError, "HrmRecruitment::WriteRepositoryInterface##build"
        end
        def save!(record:)
          raise NotImplementedError, "HrmRecruitment::WriteRepositoryInterface##save!"
        end
        def update!(record:, attributes:)
          raise NotImplementedError, "HrmRecruitment::WriteRepositoryInterface##update!"
        end
      end
    end
  end
end
