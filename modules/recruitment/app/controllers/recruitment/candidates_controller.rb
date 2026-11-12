module Recruitment
  class CandidatesController < ApplicationController
    before_action :set_candidate, only: [ :edit, :update ]
    def index
      @candidates = HrmRecruitment::Application::Queries::ListCandidates.new.call(actor: current_user, page: params[:page])
    end
    def new
      @candidate = Candidate.new(company: current_user.company)
      authorize @candidate
    end
    def edit; end
    def create
      HrmRecruitment::Application::Commands::CreateCandidate.new.call(actor: current_user, attributes: candidate_params)
      redirect_to candidates_path, notice: I18n.t("hrm_quality.messages.da_them_ung_vien")
    rescue ActiveRecord::RecordInvalid => error
      @candidate = error.record
      render :new, status: :unprocessable_content
    end
    def update
      HrmRecruitment::Application::Commands::UpdateCandidate.new.call(actor: current_user, record: @candidate, attributes: candidate_params)
      redirect_to candidates_path, notice: I18n.t("hrm_quality.messages.da_cap_nhat_ung_vien")
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_content
    end
    private
    def set_candidate
      @candidate = HrmRecruitment::Application::Queries::FindCandidate.new.call(actor: current_user, id: params[:id])
      authorize @candidate
    end
    def candidate_params = HrmRecruitment::Application::Requests::CandidateRequest.read(params)
  end
end
