class DashboardController < ApplicationController
  def index
    @stats = HrmDashboard::Application::Queries::Overview.new.call(actor: current_user)
    @requests = HrmTimeOff::Application::Queries::ListLeaveRequests.new.call(actor: current_user, recent: true)
  end
end
