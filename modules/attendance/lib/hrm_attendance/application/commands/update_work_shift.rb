module HrmAttendance
  module Application
    module Commands
      class UpdateWorkShift < Hrm::UseCase
        def initialize(read: Hrm::Container.resolve(Domain::Repositories::ShiftReadRepositoryInterface), write: Hrm::Container.resolve(Domain::Repositories::ShiftWriteRepositoryInterface))
          super()
          @read, @write = read, write
        end
        def call(actor:, id:, attributes:)
          require_actor!(actor)
          record = @read.find!(actor: actor, id: id)
          authorize!(actor, record, :update?)
          version = Integer(attributes[:lock_version].to_s, exception: false)
          if version.nil?
            record.errors.add(:lock_version, "bắt buộc khi thay đổi ca")
            raise ActiveRecord::RecordInvalid, record
          end
          raise ActiveRecord::StaleObjectError.new(record, "update") unless version == record.lock_version
          Current.set(user: actor) { @write.update!(record: record, attributes: attributes.slice(*(Requests::WorkShiftRequest::FIELDS - [ :lock_version ]))) }
        end
      end
    end
  end
end
