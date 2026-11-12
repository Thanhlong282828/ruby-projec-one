module HrmAttendance
  module Domain
    module Repositories
      class ScheduleReadRepositoryInterface
        def list(actor:, page: 1)
          raise NotImplementedError, "ScheduleReadRepositoryInterface#list"
        end
        def find!(actor:, id:)
          raise NotImplementedError, "ScheduleReadRepositoryInterface#find!"
        end
        def options(actor:, form: false)
          raise NotImplementedError, "ScheduleReadRepositoryInterface#options"
        end
        def employee!(actor:, id:)
          raise NotImplementedError, "ScheduleReadRepositoryInterface#employee!"
        end
        def period(actor:, employee:, from:, to:)
          raise NotImplementedError, "ScheduleReadRepositoryInterface#period"
        end
      end
    end
  end
end
