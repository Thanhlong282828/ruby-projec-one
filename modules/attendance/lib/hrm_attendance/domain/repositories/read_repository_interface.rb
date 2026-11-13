module HrmAttendance
  module Domain
    module Repositories
      class ReadRepositoryInterface
        def list(actor:, page: 1, status: nil, recent: false)
          raise NotImplementedError, "HrmAttendance::ReadRepositoryInterface##list"
        end
        def count(actor:, status: nil) = raise(NotImplementedError)
        def period(actor:, from:, to:, page: 1)
          raise NotImplementedError, "HrmAttendance::ReadRepositoryInterface#period"
        end
        def find!(actor:, id:)
          raise NotImplementedError, "HrmAttendance::ReadRepositoryInterface##find!"
        end
      end
    end
  end
end
