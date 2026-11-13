class DashboardController < ApplicationController
  helper OnboardingHelper
  def index
    @stats = HrmDashboard::Application::Queries::Overview.new.call(actor: current_user, period: params[:period])
  end
end
