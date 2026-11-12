module Api
  module V1
    class OrganizationStructureController < BaseController
      def tree
        render json: { data: HrmOrganization::Application::Queries::Structure.new.call(actor: current_user, view: :tree) }
      end
      def headcount
        render json: { data: HrmOrganization::Application::Queries::Structure.new.call(actor: current_user, view: :headcount) }
      end
    end
  end
end
