module HrmAttendance
  module Infrastructure
    module Persistence
      class ActiveRecordScheduleWriteRepository < Domain::Repositories::ScheduleWriteRepositoryInterface
        SNAPSHOT_FIELDS = %w[id code name start_minute end_minute unpaid_break_minutes grace_in_minutes grace_out_minutes overtime_threshold_minutes lock_version].freeze
        def build(actor:, attributes:) = ::EmployeeShiftAssignment.new(attributes.merge(company_id: actor.company_id))
        def employee!(actor:, id:) = Pundit.policy_scope!(actor, ::Employee).find(id)
        def with_employee_lock(employee:, &block) = employee.with_lock(&block)
        def save!(record:, actor:)
          shift = Pundit.policy_scope!(actor, ::WorkShift).lock.find_by(id: record.work_shift_id, active: true)
          unless shift
            record.errors.add(:work_shift, "không tồn tại, ngoài phạm vi hoặc đã ngừng dùng")
            raise ActiveRecord::RecordInvalid, record
          end
          record.work_shift = shift
          record.shift_snapshot = shift.attributes.slice(*SNAPSHOT_FIELDS).merge("captured_at"=>Time.current.iso8601)
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
