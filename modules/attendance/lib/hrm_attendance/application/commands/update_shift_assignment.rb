module HrmAttendance
  module Application
    module Commands
      class UpdateShiftAssignment < Hrm::UseCase
        def initialize(read: Hrm::Container.resolve(Domain::Repositories::ScheduleReadRepositoryInterface), write: Hrm::Container.resolve(Domain::Repositories::ScheduleWriteRepositoryInterface))
          super()
          @read, @write=read, write
        end
        def call(actor:, id:, attributes:)
          require_actor!(actor)
          record=@read.find!(actor: actor, id: id)
          authorize!(actor, record, :update?)
          @write.with_employee_lock(employee: record.employee) do
            record=@read.find!(actor: actor, id: id)
            authorize!(actor, record, :update?)
            version=Integer(attributes[:lock_version].to_s, exception: false)
            if version.nil?
              record.errors.add(:lock_version, "bắt buộc")
              raise ActiveRecord::RecordInvalid, record
            end
            raise ActiveRecord::StaleObjectError.new(record, "update") unless version==record.lock_version
            [ :employee_id, :work_shift_id, :effective_from ].each do |field|
              if attributes.key?(field) && attributes[field].to_s != record[field].to_s
                record.errors.add(field, "không được đổi sau khi tạo")
                raise ActiveRecord::RecordInvalid, record
              end
            end
            Current.set(user: actor) { @write.update!(record: record, attributes: attributes.slice(:effective_to)) }
          end
        end
      end
    end
  end
end
