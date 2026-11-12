module HrmAttendance
  module Application
    module Commands
      class CreateWorkShift < Hrm::UseCase
        def initialize(write: Hrm::Container.resolve(Domain::Repositories::ShiftWriteRepositoryInterface))
          super()
          (@write = write)
        end
        def call(actor:, attributes:)
          require_actor!(actor)
          fields = attributes.slice(*(Requests::WorkShiftRequest::FIELDS - [ :lock_version ]))
          record = @write.build(company_id: actor.company_id, attributes: fields)
          authorize!(actor, record, :create?)
          Current.set(user: actor) { @write.save!(record: record) }
        end
      end
    end
  end
end
