module HrmTimeOff
  module Application
    module Commands
      class ReviewLeave < Hrm::UseCase
        def initialize(read: Hrm::Container.resolve(Domain::Repositories::ReadRepositoryInterface), write: Hrm::Container.resolve(Domain::Repositories::WriteRepositoryInterface), events: Hrm::Container.resolve(HrmPlatform::Domain::Repositories::OutboxRepositoryInterface), rules: Domain::Services::LeaveReviewRules.new)
          @read, @write, @events, @rules = read, write, events, rules
        end
        def call(request:, reviewer:, decision:)
          query = decision == "approved" ? :approve? : :reject?
          authorize!(reviewer, request, query)
          @write.with_review_lock(request: request) do
            used = @read.used_days(employee: request.employee, year: request.starts_on.year)
            @rules.validate!(request: request, reviewer: reviewer, decision: decision, used_days: used)
            @write.review!(request: request, reviewer: reviewer, decision: decision)
            @events.append!(company_id: request.company_id, event_type: "leave_request.reviewed", payload: { record_id: request.id, decision: decision })
          end
          request
        end
      end
    end
  end
end
