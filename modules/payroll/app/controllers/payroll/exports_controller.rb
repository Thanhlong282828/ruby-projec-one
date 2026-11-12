module Payroll
  class ExportsController < ApplicationController
    rescue_from HrmPayroll::Domain::Services::PayrollCsv::InvalidSource do
      render plain: "Cần bảng lương đã chốt, hợp lệ và từ 1 đến 2000 nhân viên.", status: :unprocessable_content
    end
    rescue_from HrmPayroll::Domain::Services::PayrollCsv::IntegrityError do
      render plain: "Tệp không vượt qua kiểm tra toàn vẹn. Đã chặn tải.", status: :conflict
    end
    rescue_from HrmPayroll::Domain::Services::ExportFilters::Invalid do
      render plain: "Bộ lọc hoặc ID không hợp lệ.", status: :bad_request
    end
    def index
      @workspace = HrmPayroll::Application::Queries::ExportWorkspace.new.call(actor: current_user, before: params[:before], period: params[:period])
    end
    def show
      @export = HrmPayroll::Application::Queries::FindExport.new.call(actor: current_user, id: params[:id])
    end
    def create
      record = HrmPayroll::Application::Commands::CreateExport.new.call(actor: current_user, pay_run_id: params[:pay_run_id])
      redirect_to "/payroll/exports/#{record.id}", notice: I18n.t("hrm_quality.messages.da_luu_snapshot_csv_cua_ky_luong")
    end
    def download
      artifact = HrmPayroll::Application::Commands::DownloadExport.new.call(actor: current_user, id: params[:id])
      send_data artifact[:bytes], filename: artifact[:filename], type: "text/csv; charset=UTF-8", disposition: "attachment"
    end
  end
end
