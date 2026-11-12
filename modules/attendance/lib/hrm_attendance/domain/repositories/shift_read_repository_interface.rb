module HrmAttendance
  module Domain
    module Repositories
      class ShiftReadRepositoryInterface
        def list(actor:, page: 1)
          raise NotImplementedError, "ShiftReadRepositoryInterface#list"
        end
        def find!(actor:, id:)
          raise NotImplementedError, "ShiftReadRepositoryInterface#find!"
        end
        def attendance_options(actor:)
          raise NotImplementedError, "ShiftReadRepositoryInterface#attendance_options"
        end
      end
    end
  end
end
