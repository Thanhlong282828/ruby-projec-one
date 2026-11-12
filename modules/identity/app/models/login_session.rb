class LoginSession < ApplicationRecord
  belongs_to :user
  belongs_to :principal_user, class_name: "User"
  scope :unexpired, -> { where("expires_at > ?", Time.current) }
  validates :digest, presence: true, uniqueness: true, format: { with: /\A[a-f0-9]{64}\z/ }
  validates :expires_at, presence: true

  def self.issue!(user)
    raw = SecureRandom.urlsafe_base64(48)
    create!(user: user, principal_user_id: user.identity_id, digest: Digest::SHA256.hexdigest(raw), expires_at: 8.hours.from_now)
    raw
  end
end
