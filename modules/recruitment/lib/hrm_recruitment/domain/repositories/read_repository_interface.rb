module HrmRecruitment
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def list(actor:, page: 1)
          raise NotImplementedError, "HrmRecruitment::ReadRepositoryInterface##list"
        end
        def find!(actor:, id:)
          raise NotImplementedError, "HrmRecruitment::ReadRepositoryInterface##find!"
        end
        def count(actor:)
          raise NotImplementedError, "HrmRecruitment::ReadRepositoryInterface##count"
        end
      end
    end
  end
end
