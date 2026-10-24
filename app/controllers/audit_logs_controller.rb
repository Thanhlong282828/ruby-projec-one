class AuditLogsController < ApplicationController
  def index
    authorize AuditLog
    @logs = page(AuditLog.includes(:actor).order(id: :desc))
  end
end
