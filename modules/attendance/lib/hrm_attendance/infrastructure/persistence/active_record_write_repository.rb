module HrmAttendance
  module Infrastructure
    module Persistence
      class ActiveRecordWriteRepository < Domain::Repositories::WriteRepositoryInterface
        def build(employee:, at:) = employee.attendances.new(company_id: employee.company_id, work_date: at.to_date, checked_in_at: at)
        def already_checked_in?(employee:, work_date:) = employee.attendances.exists?(work_date: work_date)
        def save!(record:)
          record.save!
          record
        end
        def checkout!(record:, at:)
          record.with_lock { record.update!(checked_out_at: at) unless record.checked_out_at }
          record
        end
      end
    end
  end
end
