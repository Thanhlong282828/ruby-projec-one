module Recruitment
  class CandidatesController < ApplicationController
    before_action :set_candidate, only: [:edit, :update]
    def index
      @candidates = HrmRecruitment::Application::Queries::ListCandidates.new.call(actor: current_user, page: params[:page])
    end
    def new
      @candidate = Candidate.new(company: current_user.company)
      authorize @candidate
    end
    def create
      HrmRecruitment::Application::Commands::CreateCandidate.new.call(actor: current_user, attributes: candidate_params)
      redirect_to candidates_path, notice: "Đã thêm ứng viên."
    rescue ActiveRecord::RecordInvalid => error
      @candidate = error.record
      render :new, status: :unprocessable_entity
    end
    def edit; end
    def update
      HrmRecruitment::Application::Commands::UpdateCandidate.new.call(actor: current_user, record: @candidate, attributes: candidate_params)
      redirect_to candidates_path, notice: "Đã cập nhật ứng viên."
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end
    private
    def set_candidate
      @candidate = HrmRecruitment::Application::Queries::FindCandidate.new.call(actor: current_user, id: params[:id])
      authorize @candidate
    end
    def candidate_params = HrmRecruitment::Application::Requests::CandidateRequest.read(params)
  end
end
