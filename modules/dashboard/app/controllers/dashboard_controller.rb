class DashboardController < ApplicationController
  def index
    @stats = if current_user.staff?
      Rails.cache.fetch("dashboard/stats", expires_in: 2.minutes) do
        { employees: Employee.active.count, departments: Department.count, pending: LeaveRequest.pending.count, candidates: Candidate.count }
      end
    else
      { employees: policy_scope(Employee).count, departments: "—", pending: policy_scope(LeaveRequest).pending.count, candidates: "—" }
    end
    @requests = policy_scope(LeaveRequest).includes(:employee).order(created_at: :desc).limit(5)
  end
end
