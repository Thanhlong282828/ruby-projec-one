class LeaveDecisionJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  def perform(id)
    LeaveMailer.decision(LeaveRequest.find(id)).deliver_now
  end
end
