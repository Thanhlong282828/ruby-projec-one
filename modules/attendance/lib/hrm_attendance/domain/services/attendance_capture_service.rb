module HrmAttendance
  module Domain
    module Services
      class AttendanceCaptureService < Hrm::UseCase
        class InvalidState < StandardError; end
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface), workforce: Hrm::Container.resolve(HrmWorkforce::Domain::Repositories::ReadRepositoryInterface), workforce_write: Hrm::Container.resolve(HrmWorkforce::Domain::Repositories::WriteRepositoryInterface))
          super()
          @repository, @workforce, @workforce_write = repository, workforce, workforce_write
        end
        def check_in(actor:, at: Time.current)
          require_actor!(actor)
          employee = @workforce.employee_for_user!(user: actor)
          @workforce_write.with_employee_lock(employee: employee) do
            raise InvalidState, "Nhân viên đã ngừng làm việc không được chấm công." unless employee.active? || employee.probation?
            raise InvalidState, "Bạn đã chấm công hôm nay." if @repository.already_checked_in?(employee: employee, work_date: at.to_date)
            raise InvalidState, "Bạn còn ca chưa kết thúc. Hãy ra ca trước khi vào ca mới." if @repository.open_attendance?(employee: employee)
            record = @repository.build(employee: employee, at: at)
            authorize!(actor, record, :create?)
            @repository.save!(record: record)
          end
        end
      end
    end
  end
end
