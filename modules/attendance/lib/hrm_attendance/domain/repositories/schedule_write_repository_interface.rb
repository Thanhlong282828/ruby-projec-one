module HrmAttendance
  module Domain
    module Repositories
      class ScheduleWriteRepositoryInterface
        def build(actor:, attributes:)
          raise NotImplementedError, "ScheduleWriteRepositoryInterface#build"
        end
        def employee!(actor:, id:)
          raise NotImplementedError, "ScheduleWriteRepositoryInterface#employee!"
        end
        def with_employee_lock(employee:, &block)
          raise NotImplementedError, "ScheduleWriteRepositoryInterface#with_employee_lock"
        end
        def save!(record:, actor:)
          raise NotImplementedError, "ScheduleWriteRepositoryInterface#save!"
        end
        def update!(record:, attributes:)
          raise NotImplementedError, "ScheduleWriteRepositoryInterface#update!"
        end
        def destroy!(record:)
          raise NotImplementedError, "ScheduleWriteRepositoryInterface#destroy!"
        end
      end
    end
  end
end
