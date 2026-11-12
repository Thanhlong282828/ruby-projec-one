class IntegrationDeliveryJob < ApplicationJob
  queue_as :default
  def perform(id)
    Hrm::Container.resolve(HrmIntegration::Domain::Repositories::DeliveryRepositoryInterface).deliver!(id: id)
  end
end
