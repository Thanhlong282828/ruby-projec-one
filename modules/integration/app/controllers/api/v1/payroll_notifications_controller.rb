module Api
  module V1
    class PayrollNotificationsController < BaseController
      rescue_from HrmIntegration::Domain::Services::WebhookSignature::InvalidPayload,
        HrmPayroll::Domain::Services::ExportFilters::Invalid, ActionController::ParameterMissing do
        render json: { error: "invalid_payroll_notification" }, status: :bad_request
      end
      rescue_from HrmIntegration::Domain::Services::WebhookSignature::Conflict,
        HrmPayroll::Domain::Services::PayrollCsv::IntegrityError do
        render json: { error: "source_integrity_or_conflict" }, status: :conflict
      end
      rescue_from HrmIntegration::Infrastructure::Http::OutboundTransport::Unavailable do
        render json: { error: "target_configuration_unavailable" }, status: :service_unavailable
      end
      def show
        data = HrmIntegration::Application::Queries::PayrollNotificationWorkspace.new.call(actor: current_user, export_id: params[:id])
        render json: { source: data[:source].public_attributes, connections: data[:connections].map { |c| { id: c.id, name: c.name } },
          targets: data[:targets], deliveries: data[:deliveries].map(&:public_attributes) }
      end
      def create
        record = HrmIntegration::Application::Commands::QueuePayrollNotification.new.call(actor: current_user,
          export_id: params[:id], connection_id: params[:connection_id], target_key: params[:target_key])
        render json: record.public_attributes, status: :accepted
      end
    end
  end
end
