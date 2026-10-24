class DailySummaryJob < ApplicationJob
  def perform
    User.where(active: true, role: %w[admin hr]).find_each do |user|
      LeaveMailer.summary(user, LeaveRequest.pending.count).deliver_later
    end
  end
end
