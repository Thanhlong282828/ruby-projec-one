module HrmAttendance
  module Application
    module Commands
      class DeleteWorkShift < Hrm::UseCase
        def initialize(read: Hrm::Container.resolve(Domain::Repositories::ShiftReadRepositoryInterface), write: Hrm::Container.resolve(Domain::Repositories::ShiftWriteRepositoryInterface))
          super()
          @read, @write = read, write
        end
        def call(actor:, id:, lock_version:)
          require_actor!(actor)
          record = @read.find!(actor: actor, id: id)
          authorize!(actor, record, :destroy?)
          version = Integer(lock_version.to_s, exception: false)
          if version.nil?
            record.errors.add(:lock_version, "bắt buộc khi thay đổi ca")
            raise ActiveRecord::RecordInvalid, record
          end
          raise ActiveRecord::StaleObjectError.new(record, "delete") unless version == record.lock_version
          Current.set(user: actor) { @write.destroy!(record: record) }
        end
      end
    end
  end
end
