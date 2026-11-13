module Payroll
  class PayRunsController < ApplicationController
    def index
      @runs = HrmPayroll::Application::Queries::ListPayRuns.new.call(actor: current_user, page: params[:page], status: params[:status], period: params[:period])
    end
    def show
      @run = HrmPayroll::Application::Queries::FindPayRun.new.call(actor: current_user, id: params[:id])
      authorize @run
      @reconciliation = HrmPayroll::Application::Queries::ReconcilePayRun.new.call(actor: current_user, run: @run)
      @payslips = HrmPayroll::Application::Queries::ListPayslips.new.call(actor: current_user, run: @run)
    end
    def new
      @run = PayRun.new(company: current_user.company, period: Date.current.beginning_of_month)
      authorize @run
    end
    def create
      attributes = HrmPayroll::Application::Requests::PayRunRequest.read(params)
      run = HrmPayroll::Application::Commands::BuildPayRun.new.call(period: attributes[:period], actor: current_user)
      redirect_to pay_run_path(run), notice: I18n.t("hrm_quality.messages.da_tao_bang_luong_nhap")
    rescue ActiveRecord::RecordInvalid => error
      @run = error.record
      render :new, status: :unprocessable_content
    end
    def finalize
      run = HrmPayroll::Application::Queries::FindPayRun.new.call(actor: current_user, id: params[:id])
      HrmPayroll::Application::Commands::FinalizePayRun.new.call(run: run, actor: current_user)
      redirect_to run, notice: I18n.t("hrm_quality.messages.da_chot_bang_luong")
    rescue TimeOff::Review::InvalidTransition => error
      redirect_to pay_runs_path, alert: error.message
    end
  end
end
