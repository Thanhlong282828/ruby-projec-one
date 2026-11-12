module HrmAttendance
  module Application
    module Commands
      class DeleteShiftAssignment < Hrm::UseCase
        def initialize(read: Hrm::Container.resolve(Domain::Repositories::ScheduleReadRepositoryInterface), write: Hrm::Container.resolve(Domain::Repositories::ScheduleWriteRepositoryInterface))
          super()
          @read, @write=read, write
        end
        def call(actor:, id:, lock_version:)
          require_actor!(actor)
          record=@read.find!(actor: actor, id: id)
          authorize!(actor, record, :destroy?)
          @write.with_employee_lock(employee: record.employee) do
            record=@read.find!(actor: actor, id: id)
            authorize!(actor, record, :destroy?)
            version=Integer(lock_version.to_s, exception: false)
            if version.nil?
              record.errors.add(:lock_version, "bắt buộc")
              raise ActiveRecord::RecordInvalid, record
            end
            raise ActiveRecord::StaleObjectError.new(record, "delete") unless version==record.lock_version
            if record.effective_from <= Date.current
              record.errors.add(:effective_from, "không xóa phân ca đã bắt đầu; hãy cập nhật ngày kết thúc")
              raise ActiveRecord::RecordInvalid, record
            end
            Current.set(user: actor) { @write.destroy!(record: record) }
          end
        end
      end
    end
  end
end
