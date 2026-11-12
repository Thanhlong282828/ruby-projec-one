class IntegrationConnection < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  has_many :integration_webhooks, dependent: :restrict_with_error
  has_many :integration_deliveries, dependent: :restrict_with_error
  encrypts :signing_secret
  normalizes :code, with: ->(value) { value.to_s.strip.upcase }
  validates :code, presence: true, length: { maximum: 30 }, format: { with: /\A[A-Z0-9_-]+\z/ }, uniqueness: { scope: :company_id }
  validates :name, presence: true, length: { maximum: 150 }
  validates :public_id, format: { with: /\A[0-9a-f-]{36}\z/ }, uniqueness: true
  validates :signing_secret, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :active, inclusion: { in: [ true, false ] }
  validate do
    errors.add(:base, "Không được đổi định danh kết nối") if persisted? && (will_save_change_to_public_id? || will_save_change_to_code?)
  end
  def public_attributes = attributes.slice("id", "public_id", "code", "name", "active", "lock_version", "created_at")
  def serializable_hash(options = nil) = super(options).except("signing_secret")
end
