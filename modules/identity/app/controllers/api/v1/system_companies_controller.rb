module Api
  module V1
    class SystemCompaniesController < BaseController
      rescue_from HrmIdentity::Domain::Services::TenantInput::Invalid do
        render json: { error: "invalid_tenant_input" }, status: :bad_request
      end
      def index
        data = HrmIdentity::Application::Queries::SystemCompanies.new.call(actor: current_user, before: params[:before])
        render json: { companies: data[:companies].map { |c| { id: c.id, code: c.code, name: c.name, active: c.active?, branches: data[:branches].fetch(c.id, 0) } }, total: data[:total], next_before: data[:next_before] }
      end
      def show
        data = HrmIdentity::Application::Queries::SystemCompany.new.call(actor: current_user, id: params[:id])
        render json: { company: data[:company].as_json(only: [ :id, :code, :name, :active, :lock_version ]), roles: data[:roles], memberships: data[:memberships], branches: data[:branches] }
      end
      def create
        attrs = params.expect(company: [ :code, :name ]).to_h.symbolize_keys
        record = HrmIdentity::Application::Commands::CreateSystemCompany.new.call(actor: current_user, attributes: attrs)
        render json: record.as_json(only: [ :id, :code, :name, :active, :lock_version ]), status: :created
      end
      def update
        attrs = params.expect(company: [ :name, :active ]).to_h.symbolize_keys
        record = HrmIdentity::Application::Commands::UpdateSystemCompany.new.call(actor: current_user, id: params[:id], attributes: attrs, lock_version: params[:lock_version])
        render json: record.as_json(only: [ :id, :code, :name, :active, :lock_version ])
      end
      def membership
        record = HrmIdentity::Application::Commands::AssignCompanyMembership.new.call(actor: current_user, company_id: params[:id], principal_id: params[:principal_id], role: params[:role])
        render json: { id: record.id, company_id: record.company_id, principal_id: record.principal_user_id, role: record.role }, status: :created
      end
    end
  end
end
