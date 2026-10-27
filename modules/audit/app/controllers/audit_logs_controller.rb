class AuditLogsController < ApplicationController
  def index
    @logs = HrmAudit::Application::Queries::ListAuditLogs.new.call(actor: current_user, page: params[:page])
  end
end
