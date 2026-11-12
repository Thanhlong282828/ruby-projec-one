module Organization
  class BranchesController < ApplicationController
    rescue_from ActiveRecord::RecordInvalid do |error|
      render plain: error.record.errors.full_messages.join("; "), status: :unprocessable_content
    end
    rescue_from HrmOrganization::Domain::Services::BranchFilters::Invalid do |error|
      render plain: error.message, status: :unprocessable_content
    end
    def index
      @workspace = HrmOrganization::Application::Queries::Branches.new.call(actor: current_user, q: params[:q], status: params[:status], after: params[:after])
    end
    def create
      data = params.expect(branch: [ :code, :name, :parent_id, :effective_from, :headcount_limit ]).to_h.symbolize_keys
      record = HrmOrganization::Application::Commands::CreateRecord.new.call(actor: current_user, resource: "organization_units", attributes: data.merge(unit_type: "branch"))
      redirect_to "/organization/organization-units/#{record.id}", notice: I18n.t("hrm_quality.messages.da_tao_chi_nhanh_thuoc_cong_ty_hien_tai")
    end
  end
end
