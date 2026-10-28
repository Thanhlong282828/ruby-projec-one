module HrmRecruitment
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        def list(actor:, page: 1) = Hrm::Pagination.call(Pundit.policy_scope!(actor, ::Candidate).order(created_at: :desc), page).to_a
        def find!(actor:, id:) = Pundit.policy_scope!(actor, ::Candidate).find(id)
        def count(actor:) = Pundit.policy_scope!(actor, ::Candidate).count
      end
    end
  end
end
