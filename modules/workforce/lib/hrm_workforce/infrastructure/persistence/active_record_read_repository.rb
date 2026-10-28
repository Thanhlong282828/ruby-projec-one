module HrmWorkforce
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        def employees(actor:, page: 1, search: nil, api: false)
          scope = Pundit.policy_scope!(actor, ::Employee).includes(:department).order(api ? :id : :employee_code)
          if search.present?
            term = "%#{::Employee.sanitize_sql_like(search.to_s)}%"
            scope = scope.where("full_name LIKE ? OR employee_code LIKE ?", term, term)
          end
          Hrm::Pagination.call(scope, page).to_a
        end
        def employee!(actor:, id:) = Pundit.policy_scope!(actor, ::Employee).includes(:department).find(id)
        def departments(actor:, page: 1) = Hrm::Pagination.call(Pundit.policy_scope!(actor, ::Department).order(:name), page).to_a
        def department!(actor:, id:) = Pundit.policy_scope!(actor, ::Department).find(id)
        def form_options(actor:)
          raise Pundit::NotAuthorizedError unless actor&.allowed?("employees.create") || actor&.allowed?("employees.update")
          { departments: ::Department.where(company_id: actor.company_id).order(:name).to_a }
        end
        def employee_for_user!(user:) = ::Employee.find_by!(company_id: user.company_id, user_id: user.id)
        def employee_for_leave!(actor:, id:) = Pundit.policy_scope!(actor, ::Employee).includes(:department).find(id)
        def active_employees(company_id:) = ::Employee.where(company_id: company_id).active.to_a
        def employee_count(actor:) = Pundit.policy_scope!(actor, ::Employee).active.count
        def department_count(actor:) = Pundit.policy_scope!(actor, ::Department).count
      end
    end
  end
end
