class DailySummaryJob < ApplicationJob
  def perform
    repository = Hrm::Container.resolve(HrmIdentity::Domain::Repositories::AdministrationRepositoryInterface)
    repository.active_companies.each do |company|
      summary = HrmTimeOff::Application::Queries::DailySummary.new.call(company_id: company.id)
      summary[:recipients].each { |user| LeaveMailer.summary(user, summary[:pending]).deliver_later }
    end
  end
end
