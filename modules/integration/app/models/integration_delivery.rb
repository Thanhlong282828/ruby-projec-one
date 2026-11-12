class IntegrationDelivery < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :payroll_export, optional: true
  belongs_to :integration_connection
  belongs_to :requested_by, class_name: "User"
  has_many :integration_delivery_attempts, dependent: :restrict_with_error
  encrypts :payload
  validates :target_key, format: { with: /\A[a-z][a-z0-9_-]{0,39}\z/ }
  validates :idempotency_key, format: { with: /\A[A-Za-z0-9][A-Za-z0-9_.:-]{0,99}\z/ }
  validates :status, inclusion: { in: %w[queued retry_wait delivered dead_letter blocked] }
  validates :payload, :event_id, :body_digest, :available_at, presence: true
  validate do
    errors.add(:base, "Liên kết phải cùng company") if integration_connection&.company_id != company_id || requested_by&.company_id != company_id
    immutable = %w[payroll_export_id company_id integration_connection_id requested_by_id target_key event_id idempotency_key payload body_digest]
    errors.add(:base, "Không được đổi nội dung gốc") if persisted? && immutable.any? { |key| will_save_change_to_attribute?(key) }
  end
  def public_attributes
    (attribute_names - %w[payload body_digest]).index_with { |name| self[name] }
  end
  def serializable_hash(_options = nil) = public_attributes
end
