module Integration
  class PayrollNotificationsController < ApplicationController
    rescue_from HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload,
      HrmPayroll::Domain::Services::ExportFilters::Invalid, ActionController::ParameterMissing do
      render plain: "Nguồn hoặc đích gửi không hợp lệ.", status: :bad_request
    end
    rescue_from HrmIntegration::Domain::Services::WebhookSignature::Conflict,
      HrmPayroll::Domain::Services::PayrollCsv::IntegrityError do
      render plain: "Đã chặn do nguồn không toàn vẹn hoặc nội dung xung đột.", status: :conflict
    end
    rescue_from HrmIntegration::Infrastructure::Http::OutboundTransport::Unavailable do
      render plain: "Cấu hình đích chưa sẵn sàng.", status: :service_unavailable
    end
    def show
      @workspace = HrmIntegration::Application::Queries::PayrollNotificationWorkspace.new.call(actor: current_user, export_id: params[:id])
    end
    def create
      record = HrmIntegration::Application::Commands::QueuePayrollNotification.new.call(actor: current_user,
        export_id: params[:id], connection_id: params[:connection_id], target_key: params[:target_key])
      redirect_to "/integration/outbound/#{record.id}", notice: I18n.t("hrm_quality.messages.da_xep_hang_thong_bao_snapshot_khong_gui_noi_dung_csv")
    end
  end
end
