module Api
  module V1
    class PayrollExportsController < BaseController
      rescue_from HrmPayroll::Domain::Services::PayrollCsv::InvalidSource do
        render json: { error: "finalized_valid_payroll_required" }, status: :unprocessable_content
      end
      rescue_from HrmPayroll::Domain::Services::PayrollCsv::IntegrityError do
        render json: { error: "artifact_integrity_failed" }, status: :conflict
      end
      rescue_from HrmPayroll::Domain::Services::ExportFilters::Invalid do
        render json: { error: "invalid_export_filter" }, status: :bad_request
      end
      def index
        data = HrmPayroll::Application::Queries::ExportWorkspace.new.call(actor: current_user, before: params[:before], period: params[:period])
        render json: { records: data[:records].map(&:public_attributes), count: data[:count], period: data[:period], next_before: data[:next_before] }
      end
      def show
        data = HrmPayroll::Application::Queries::FindExport.new.call(actor: current_user, id: params[:id])
        render json: { record: data[:record].public_attributes, accesses: data[:accesses].map(&:public_attributes) }
      end
      def create
        record = HrmPayroll::Application::Commands::CreateExport.new.call(actor: current_user, pay_run_id: params[:pay_run_id])
        render json: record.public_attributes, status: record.previously_new_record? ? :created : :ok
      end
      def download
        artifact = HrmPayroll::Application::Commands::DownloadExport.new.call(actor: current_user, id: params[:id])
        send_data artifact[:bytes], filename: artifact[:filename], type: "text/csv; charset=UTF-8", disposition: "attachment"
      end
    end
  end
end
