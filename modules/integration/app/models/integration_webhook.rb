class IntegrationWebhook < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :integration_connection
  encrypts :payload
  encrypts :review_note
  validates :event_id, format: { with: /\A[A-Za-z0-9][A-Za-z0-9_.:-]{0,99}\z/ }, uniqueness: { scope: :integration_connection_id }
  validates :event_type, format: { with: /\A[a-z][a-z0-9_.-]{0,99}\z/ }
  validates :body_digest, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :payload, presence: true
  validates :status, inclusion: { in: %w[received acknowledged rejected] }
  validates :review_note, length: { maximum: 1000 }, allow_nil: true
  validate do
    errors.add(:integration_connection, "phải cùng company") if integration_connection && integration_connection.company_id != company_id
    immutable = %w[integration_connection_id event_id event_type body_digest payload]
    errors.add(:base, "Không được đổi dữ liệu gốc webhook") if persisted? && immutable.any? { |key| will_save_change_to_attribute?(key) }
  end
  def public_attributes = attributes.slice("id", "integration_connection_id", "event_id", "event_type", "status", "lock_version", "reviewed_at", "created_at")
  def serializable_hash(options = nil) = super(options).except("payload", "review_note", "body_digest")
end
