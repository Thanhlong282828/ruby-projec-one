module HrmTimeOff
  module Domain
    module Services
      class LeaveReviewRules
        class InvalidTransition < StandardError; end
        def validate!(request:, reviewer:, decision:, used_days:)
          raise Pundit::NotAuthorizedError unless reviewer&.allowed?("leave.review") && reviewer.company_id == request.company_id
          raise Pundit::NotAuthorizedError if request.employee.user_id == reviewer.id
          raise InvalidTransition, "Invalid decision" unless %w[approved rejected].include?(decision)
          raise InvalidTransition, "Request already reviewed" unless request.pending?
          if decision == "approved" && used_days + request.days > request.employee.annual_leave_days
            raise InvalidTransition, "Annual leave balance exceeded"
          end
        end
      end
    end
  end
end
