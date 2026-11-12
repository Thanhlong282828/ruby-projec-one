module HrmAttendance
  module Application
    module Queries
      class WorkShiftWorkspace < Hrm::UseCase
        def initialize(repository: Hrm::Container.resolve(Domain::Repositories::ShiftReadRepositoryInterface))
          super()
          (@repository = repository)
        end
        def call(actor:, id: nil, page: 1, form: false)
          if id
            require_actor!(actor)
            record = @repository.find!(actor: actor, id: id)
            authorize!(actor, record, form ? :update? : :show?)
            { record: record, attendance_options: form ? [] : @repository.attendance_options(actor: actor) }
          elsif form
            record = ::WorkShift.new(company_id: actor&.company_id, start_minute: 480, end_minute: 1020, unpaid_break_minutes: 60)
            authorize!(actor, record, :create?)
            { record: record, attendance_options: [] }
          else
            authorize!(actor, ::WorkShift, :index?)
            { records: @repository.list(actor: actor, page: page) }
          end
        end
      end
    end
  end
end
