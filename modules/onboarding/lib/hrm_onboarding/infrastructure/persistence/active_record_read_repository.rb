module HrmOnboarding
  module Infrastructure
    module Persistence
      class ActiveRecordReadRepository < Domain::Repositories::ReadRepositoryInterface
        def count(actor:) = Pundit.policy_scope!(actor, ::OnboardingCase).count
        def board(actor:, status: nil, page: 1)
          scope = Pundit.policy_scope!(actor, ::OnboardingCase)
          counts = scope.group(:status).count
          scope = scope.where(status: status) if status
          scope = scope.includes(:employee).order(start_date: :desc, id: :desc)
          records = status ? Hrm::Pagination.call(scope, page).to_a : scope.limit(100).to_a
          { counts: counts, status: status, cases: records }
        end
        def find!(actor:, id:) = Pundit.policy_scope!(actor, ::OnboardingCase).includes(:employee).find(positive_id!(id))
        def employee_options(actor:) = Pundit.policy_scope!(actor, ::Employee).active.order(:full_name).limit(200).to_a
        private
        def positive_id!(id)
          raise ActiveRecord::RecordNotFound unless (id.is_a?(Integer) && id.positive?) || (id.is_a?(String) && /\A[1-9]\d{0,17}\z/.match?(id))
          id
        end
      end
    end
  end
end
