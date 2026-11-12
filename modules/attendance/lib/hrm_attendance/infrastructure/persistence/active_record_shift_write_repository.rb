module HrmAttendance
  module Infrastructure
    module Persistence
      class ActiveRecordShiftWriteRepository < Domain::Repositories::ShiftWriteRepositoryInterface
        def build(company_id:, attributes:) = ::WorkShift.new(attributes.merge(company_id: company_id))
        def save!(record:)
          record.save!
          record
        end
        def update!(record:, attributes:)
          record.update!(attributes)
          record
        end
        def destroy!(record:) = record.destroy!
      end
    end
  end
end
