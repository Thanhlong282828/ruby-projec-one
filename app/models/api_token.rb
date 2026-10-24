class ApiToken < ApplicationRecord
  belongs_to :user
  scope :valid_now, -> { where("expires_at > ?", Time.current) }
  def self.issue!(user)
    raw = SecureRandom.urlsafe_base64(48)
    create!(user: user, digest: Digest::SHA256.hexdigest(raw), expires_at: 8.hours.from_now)
    raw
  end
end
