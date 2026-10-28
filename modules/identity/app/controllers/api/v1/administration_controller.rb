module Api
  module V1
    class AdministrationController < BaseController
      rescue_from HrmIdentity::Domain::InvalidAdministration do |error|
        render json: { error: "invalid_access_change", details: error.message }, status: :unprocessable_entity
      end
      def company
        data = query(:company)
        render json: { data: data[:company].attributes.slice("id", "code", "name") }
      end
      def accounts
        data = query(:accounts)
        render json: { data: data[:accounts].map { |user| user.attributes.slice("id", "email", "role", "active", "company_id") } }
      end
      def roles
        data = query(:roles)
        render json: { data: data[:roles].map { |role| { id: role.id, key: role.key, name: role.name, permissions: role.permissions.map(&:key) } } }
      end
      def save_company = apply(:company)
      def save_account = apply(:accounts, id: params[:id])
      def save_role = apply(:roles, id: params[:id])
      private
      def query(area) = HrmIdentity::Application::Queries::Administration.new.call(actor: current_user, area: area)
      def apply(area, id: nil)
        record = HrmIdentity::Application::Commands::ManageCompanyAccess.new.call(actor: current_user, area: area, id: id, attributes: HrmIdentity::Application::Requests::AdministrationRequest.read(params, area: area))
        if area == :roles && id.nil?
          render json: { data: record.attributes.slice("id", "key", "name", "company_id") }, status: :created
        else
          head :no_content
        end
      end
    end
  end
end
