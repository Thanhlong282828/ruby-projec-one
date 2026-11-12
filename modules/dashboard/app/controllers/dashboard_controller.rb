class DashboardController < ApplicationController
  def index
    @stats = HrmDashboard::Application::Queries::Overview.new.call(actor: current_user)
    @requests = if policy(LeaveRequest).index?
      HrmTimeOff::Application::Queries::ListLeaveRequests.new.call(actor: current_user, recent: true)
    else
      []
    end
  end
end
