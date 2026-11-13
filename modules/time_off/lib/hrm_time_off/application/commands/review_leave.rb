# typed: strict

module HrmTimeOff
  module Application
    module Commands
      class ReviewLeave < Hrm::UseCase
        extend T::Sig
        sig { params(read: Domain::Repositories::ReadRepositoryInterface, write: Domain::Repositories::WriteRepositoryInterface, events: HrmPlatform::Domain::Repositories::OutboxRepositoryInterface, rules: Domain::Services::LeaveReviewRules).void }
        def initialize(read: T.cast(Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface), Domain::Repositories::ReadRepositoryInterface), write: T.cast(Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface), Domain::Repositories::WriteRepositoryInterface), events: T.cast(Hrm::Container.resolve(HrmPlatform::Domain::Repositories::OutboxRepositoryInterface), HrmPlatform::Domain::Repositories::OutboxRepositoryInterface), rules: Domain::Services::LeaveReviewRules.new)
          super()
          # Container is dynamic/reloadable; casts restore the actual repository contracts.
          @read = T.let(read, Domain::Repositories::ReadRepositoryInterface)
          @write = T.let(write, Domain::Repositories::WriteRepositoryInterface)
          @events = T.let(events, HrmPlatform::Domain::Repositories::OutboxRepositoryInterface)
          @rules = T.let(rules, Domain::Services::LeaveReviewRules)
        end
        # Preserve rules/authorization exceptions for nil or malformed external decisions.
        sig { params(request: T.nilable(LeaveRequest), reviewer: T.nilable(User), decision: Object).returns(LeaveRequest) }
        def call(request:, reviewer:, decision:)
          query = decision == "approved" ? :approve? : :reject?
          authorize!(reviewer, request, query)
          reviewer = T.must(reviewer) # authorize! rejects nil before narrowing.
          request = T.must(request) # Pundit rejects a missing record first.
          @write.with_review_lock(request: request) do
            authorize!(reviewer, request, query)
            used = @read.used_days(employee: T.must(request.employee), year: request.starts_on.year, lock: true)
            @rules.validate!(request: request, reviewer: reviewer, decision: decision, used_days: used)
            @write.review!(request: request, reviewer: reviewer, decision: T.cast(decision, String)) # Rules reject malformed values before this narrowing.
            @events.append!(company_id: request.company_id, event_type: "leave_request.reviewed", payload: { record_id: request.id, decision: decision })
          end
          request
        end
      end
    end
  end
end
