module HrmAttendance
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def list(actor:, page: 1)
          raise NotImplementedError, "HrmAttendance::ReadRepositoryInterface##list"
        end
        def find!(actor:, id:)
          raise NotImplementedError, "HrmAttendance::ReadRepositoryInterface##find!"
        end
      end
    end
  end
end
