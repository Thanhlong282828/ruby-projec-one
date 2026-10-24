module Recruitment
  class CandidatesController < ApplicationController
    before_action :set_candidate, only: [:edit, :update]
    def index
      authorize Candidate
      @candidates = page(policy_scope(Candidate).order(created_at: :desc))
    end
    def new
      @candidate = Candidate.new
      authorize @candidate
    end
    def create
      @candidate = Candidate.new(candidate_params)
      authorize @candidate
      @candidate.save ? redirect_to(candidates_path, notice: "Đã thêm ứng viên.") : render(:new, status: :unprocessable_entity)
    end
    def edit; end
    def update
      @candidate.update(candidate_params) ? redirect_to(candidates_path, notice: "Đã cập nhật ứng viên.") : render(:edit, status: :unprocessable_entity)
    end
    private
    def set_candidate
      @candidate = policy_scope(Candidate).find(params[:id])
      authorize @candidate
    end
    def candidate_params = params.require(:candidate).permit(:full_name, :email, :position, :stage, :notes)
  end
end
