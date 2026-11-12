module Api
  module V1
    class BranchesController < BaseController
      rescue_from HrmOrganization::Domain::Services::BranchFilters::Invalid do |error|
        render json: { error: error.message }, status: :unprocessable_content
      end
      def index
        data = HrmOrganization::Application::Queries::Branches.new.call(actor: current_user, q: params[:q], status: params[:status], after: params[:after])
        render json: { total: data[:total], matching: data[:matching], next_after: data[:next_after], filters: { q: data[:q], status: data[:status] }, records: data[:records].map { |r| r.as_json(only: [ :id, :company_id, :code, :name, :parent_id, :unit_type, :effective_from, :effective_to, :lock_version ]) } }
      end
      def create
        data = params.expect(branch: [ :code, :name, :parent_id, :effective_from, :headcount_limit ]).to_h.symbolize_keys
        record = HrmOrganization::Application::Commands::CreateRecord.new.call(actor: current_user, resource: "organization_units", attributes: data.merge(unit_type: "branch"))
        render json: { id: record.id, company_id: record.company_id, unit_type: record.unit_type }, status: :created
      end
    end
  end
end
