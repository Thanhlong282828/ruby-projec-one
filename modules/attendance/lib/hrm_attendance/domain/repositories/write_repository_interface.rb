module HrmAttendance
  module Domain
    module Repositories
      class WriteRepositoryInterface
        def build(employee:, at:)
          raise NotImplementedError, "HrmAttendance::WriteRepositoryInterface##build"
        end
        def already_checked_in?(employee:, work_date:)
          raise NotImplementedError, "HrmAttendance::WriteRepositoryInterface##already_checked_in?"
        end
        def save!(record:)
          raise NotImplementedError, "HrmAttendance::WriteRepositoryInterface##save!"
        end
        def checkout!(record:, at:)
          raise NotImplementedError, "HrmAttendance::WriteRepositoryInterface##checkout!"
        end
      end
    end
  end
end
