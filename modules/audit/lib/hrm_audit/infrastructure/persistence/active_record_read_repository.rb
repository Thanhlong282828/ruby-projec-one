module HrmAudit
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        def list(actor:, page: 1) = Hrm::Pagination.call(Pundit.policy_scope!(actor, ::AuditLog).includes(:actor).order(id: :desc), page).to_a
      end
    end
  end
end
