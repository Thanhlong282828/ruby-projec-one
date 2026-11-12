module Onboarding
  class CasesController < ApplicationController
    helper OnboardingHelper
    rescue_from ActiveRecord::RecordInvalid do |error|
      render plain: error.record.errors.full_messages.join("; "), status: :unprocessable_content
    end
    rescue_from ActionController::ParameterMissing do
      render plain: "Thiếu dữ liệu hồ sơ", status: :bad_request
    end
    rescue_from ActiveRecord::RecordNotUnique do
      render plain: "Hồ sơ tiếp nhận đã tồn tại cho ngày này", status: :conflict
    end
    def index
      @workspace = HrmOnboarding::Application::Queries::Workspace.new.call(actor: current_user)
    end
    def show
      @record = HrmOnboarding::Application::Queries::FindCase.new.call(actor: current_user, id: params[:id])
    end
    def new
      @employees = HrmOnboarding::Application::Queries::EmployeeOptions.new.call(actor: current_user)
    end
    def create
      record = HrmOnboarding::Application::Commands::CreateCase.new.call(actor: current_user, attributes: HrmOnboarding::Application::Requests::CaseParameters.read(params))
      redirect_to "/onboarding/cases/#{record.id}", notice: I18n.t("hrm_quality.messages.da_tao_ho_so_tiep_nhan")
    end
    def transition
      record = HrmOnboarding::Application::Commands::TransitionCase.new.call(actor: current_user, id: params[:id], status: params[:status], lock_version: params[:lock_version])
      redirect_to "/onboarding/cases/#{record.id}", notice: I18n.t("hrm_quality.messages.da_chuyen_trang_thai")
    end
    def complete
      record = HrmOnboarding::Application::Commands::CompleteChecklist.new.call(actor: current_user, id: params[:id], code: params[:code], lock_version: params[:lock_version])
      redirect_to "/onboarding/cases/#{record.id}", notice: I18n.t("hrm_quality.messages.da_hoan_tat_checklist")
    end
  end
end
