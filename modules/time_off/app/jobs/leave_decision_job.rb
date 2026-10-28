class LeaveDecisionJob < ApplicationJob
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  def perform(id, company_id = nil)
    # Legacy jobs queued before tenancy refer only to data backfilled into XINVIEC.
    company_id ||= Hrm::Container.resolve(HrmIdentity::Domain::Repositories::AdministrationRepositoryInterface).company_id_for_code!(code: "XINVIEC")
    LeaveMailer.decision(Hrm::Container.resolve(HrmTimeOff::Domain::Repositories::ReadRepositoryInterface).find_for_mail!(id: id, company_id: company_id)).deliver_now
  end
end
