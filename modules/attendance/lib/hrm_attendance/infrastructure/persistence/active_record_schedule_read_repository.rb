module HrmAttendance
  module Infrastructure
    module Persistence
      class ActiveRecordScheduleReadRepository < Domain::Repositories::ScheduleReadRepositoryInterface
        def list(actor:, page: 1) = Hrm::Pagination.call(Pundit.policy_scope!(actor, ::EmployeeShiftAssignment).includes(:employee, :work_shift).order(effective_from: :desc, id: :desc), page).to_a
        def find!(actor:, id:) = Pundit.policy_scope!(actor, ::EmployeeShiftAssignment).includes(:employee, :work_shift).find(id)
        def options(actor:, form: false)
          employees = form ? Pundit.policy_scope!(actor, ::Employee) : employee_scope(actor)
          { employees: employees.order(:full_name, :id).limit(200).map { |e| [ e.full_name, e.id ] },
            shifts: form ? Pundit.policy_scope!(actor, ::WorkShift).where(active: true).order(:code).limit(200).map { |s| [ "#{s.code} · #{s.name}", s.id ] } : [] }
        end
        def employee!(actor:, id:)
          raise ActiveRecord::RecordNotFound unless id.is_a?(String) || id.is_a?(Integer)
          number = Integer(id.to_s, exception: false)
          raise ActiveRecord::RecordNotFound unless number && number.positive?
          employee_scope(actor).find(number)
        end
        def period(actor:, employee:, from:, to:)
          { assignments: Pundit.policy_scope!(actor, ::EmployeeShiftAssignment).where(employee_id: employee.id)
            .where("effective_from <= ? AND (effective_to IS NULL OR effective_to >= ?)", to, from).order(:effective_from).to_a,
            attendances: Pundit.policy_scope!(actor, ::Attendance).where(employee_id: employee.id, work_date: from..to).index_by(&:work_date) }
        end
        private
        def employee_scope(actor)
          return ::Employee.none unless actor&.enabled_for_access? && (actor.allowed?("shift_assignments.read") || actor.allowed?("shift_assignments.read_all"))
          scope = ::Employee.where(company_id: actor.company_id)
          actor.allowed?("shift_assignments.read_all") ? scope : scope.where(user_id: actor.id)
        end
      end
    end
  end
end
