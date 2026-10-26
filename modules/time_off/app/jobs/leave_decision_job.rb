class LeaveDecisionJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  def perform(id)
    LeaveMailer.decision(Hrm::Container.resolve(HrmTimeOff::Domain::Repositories::ReadRepositoryInterface).find_for_mail!(id: id)).deliver_now
  end
end
