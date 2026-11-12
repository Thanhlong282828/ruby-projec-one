module HrmAttendance
  module Application
    module Commands
      class CreateShiftAssignment < Hrm::UseCase
        def initialize(write: Hrm::Container.resolve(Domain::Repositories::ScheduleWriteRepositoryInterface))
          super()
          (@write=write)
        end
        def call(actor:, attributes:)
          require_actor!(actor)
          record=@write.build(actor: actor, attributes: attributes.slice(:employee_id, :work_shift_id, :effective_from, :effective_to))
          authorize!(actor, record, :create?)
          employee=@write.employee!(actor: actor, id: record.employee_id)
          @write.with_employee_lock(employee: employee) do
            record.employee=employee
            Current.set(user: actor) { @write.save!(record: record, actor: actor) }
          end
        end
      end
    end
  end
end
