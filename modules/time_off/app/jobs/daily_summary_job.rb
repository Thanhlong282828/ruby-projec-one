class DailySummaryJob < ApplicationJob
  def perform
    summary = HrmTimeOff::Application::Queries::DailySummary.new.call
    summary[:recipients].each { |user| LeaveMailer.summary(user, summary[:pending]).deliver_later }
  end
end
