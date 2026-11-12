class IntegrationDeliveryAttempt < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :integration_delivery
  validates :outcome, inclusion: { in: %w[delivered http_error transport_error target_unavailable] }
  validates :sequence, numericality: { only_integer: true, greater_than: 0 }
  validate do
    errors.add(:base, "Lịch sử chỉ được ghi thêm") if persisted? && changed?
    errors.add(:base, "Company không hợp lệ") if integration_delivery&.company_id != company_id
  end
  before_destroy { throw :abort }
end
