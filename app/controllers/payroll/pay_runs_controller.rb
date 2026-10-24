module Payroll
  class PayRunsController < ApplicationController
    def index
      authorize PayRun
      @runs = page(policy_scope(PayRun).order(period: :desc))
    end
    def show
      @run = policy_scope(PayRun).find(params[:id])
      authorize @run
    end
    def new
      @run = PayRun.new(period: Date.current.beginning_of_month)
      authorize @run
    end
    def create
      authorize PayRun
      run = BuildRun.call(period: params.require(:pay_run)[:period], actor: current_user)
      redirect_to pay_run_path(run), notice: "Đã tạo bảng lương nháp."
    rescue ActiveRecord::RecordInvalid => error
      @run = error.record
      render :new, status: :unprocessable_entity
    end
    def finalize
      run = policy_scope(PayRun).find(params[:id])
      authorize run, :update?
      FinalizeRun.call(run: run, actor: current_user)
      redirect_to run, notice: "Đã chốt bảng lương."
    rescue TimeOff::Review::InvalidTransition => error
      redirect_to pay_runs_path, alert: error.message
    end
  end
end
