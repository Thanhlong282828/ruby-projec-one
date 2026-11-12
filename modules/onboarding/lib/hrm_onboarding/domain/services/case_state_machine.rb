module HrmOnboarding
  module Domain
    module Services
      class CaseStateMachine
        TRANSITIONS = {
          "draft" => %w[ready preboarding cancelled], "ready" => %w[preboarding cancelled],
          "preboarding" => %w[in_progress blocked cancelled],
          "in_progress" => %w[blocked probation_review completed cancelled],
          "blocked" => %w[preboarding in_progress cancelled],
          "probation_review" => %w[completed in_progress cancelled],
          "completed" => [], "cancelled" => []
        }.freeze
        def self.targets(status) = TRANSITIONS.fetch(status, [])
        def self.allowed?(from, to) = targets(from).include?(to)
      end
    end
  end
end
