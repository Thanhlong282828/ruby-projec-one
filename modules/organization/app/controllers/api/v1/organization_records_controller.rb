module Api
  module V1
    class OrganizationRecordsController < BaseController
      rescue_from ActiveRecord::RecordNotDestroyed do |error|
        render json: { error: "record_in_use", details: error.record.errors.full_messages }, status: :conflict
      end
      def index
        records = HrmOrganization::Application::Queries::ListRecords.new.call(actor: current_user, resource: resource, page: params[:page])
        render json: { data: records.map { |r| serialize(r) } }
      end
      def show
        record = HrmOrganization::Application::Queries::FindRecord.new.call(actor: current_user, resource: resource, id: params[:id])
        render json: { data: serialize(record) }
      end
      def create
        record = HrmOrganization::Application::Commands::CreateRecord.new.call(actor: current_user, resource: resource, attributes: record_params)
        render json: { data: serialize(record) }, status: :created
      end
      def update
        record = HrmOrganization::Application::Commands::UpdateRecord.new.call(actor: current_user, resource: resource, id: params[:id], attributes: record_params)
        render json: { data: serialize(record) }
      end
      def destroy
        HrmOrganization::Application::Commands::DeleteRecord.new.call(actor: current_user, resource: resource, id: params[:id])
        head :no_content
      end
      private
      def resource = request.path_parameters.fetch(:resource)
      def record_params = HrmOrganization::Application::Requests::RecordRequest.read(params, resource: resource)
      def serialize(record) = record.attributes.slice("id", "company_id", *HrmOrganization::Domain::Resources.fetch(resource).fetch(:fields).keys.map(&:to_s))
    end
  end
end
