module TimeOff
  class Review
    class InvalidTransition < StandardError; end
    def self.call(request:, reviewer:, decision:)
      raise Pundit::NotAuthorizedError unless reviewer&.active? && (reviewer.staff? || reviewer.manager?)
      raise Pundit::NotAuthorizedError if request.employee.user_id == reviewer.id
      raise InvalidTransition, "Invalid decision" unless %w[approved rejected].include?(decision)
      # Serialize reviews per employee, including simultaneous approvals of different requests.
      request.employee.with_lock do
        request.lock!
        raise InvalidTransition, "Request already reviewed" unless request.pending?
        if decision == "approved"
          year = request.starts_on.year
          used = request.employee.leave_requests.approved.where(starts_on: Date.new(year)..Date.new(year, 12, 31)).sum { |leave| leave.days }
          raise InvalidTransition, "Annual leave balance exceeded" if used + request.days > request.employee.annual_leave_days
        end
        request.update!(status: decision, reviewer: reviewer, reviewed_at: Time.current)
        OutboxEvent.create!(event_type: "leave_request.reviewed", payload: { record_id: request.id, decision: decision })
      end
      request
    end
  end
end
