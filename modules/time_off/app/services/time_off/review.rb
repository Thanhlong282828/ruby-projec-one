module TimeOff
  class Review
    InvalidTransition = HrmTimeOff::Domain::Services::LeaveReviewRules::InvalidTransition
    def self.call(request:, reviewer:, decision:)
      HrmTimeOff::Application::Commands::ReviewLeave.new.call(request: request, reviewer: reviewer, decision: decision)
    end
  end
end
