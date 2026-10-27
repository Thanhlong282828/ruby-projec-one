module HrmPayroll
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        def list(actor:, page: 1) = Hrm::Pagination.call(Pundit.policy_scope!(actor, ::PayRun).order(period: :desc), page).to_a
        def find!(actor:, id:) = Pundit.policy_scope!(actor, ::PayRun).find(id)
        def payslips(run:) = run.payslips.includes(:employee).to_a
      end
    end
  end
end
