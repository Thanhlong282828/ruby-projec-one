class IntegrationDispatchJob < ApplicationJob
  queue_as :default
  def perform
    Hrm::Container.resolve(HrmIntegration::Domain::Repositories::DeliveryRepositoryInterface).due_ids.each do |id|
      IntegrationDeliveryJob.perform_later(id)
    end
  end
end
