class SystemGrant < ApplicationRecord
  belongs_to :user
  belongs_to :permission
  KEYS = %w[system.companies.read system.companies.manage].freeze
  validates :permission_id, uniqueness: { scope: :user_id }
  validate do
    errors.add(:user, "chỉ cấp cho định danh gốc") if user&.principal_user_id
    errors.add(:permission, "không phải quyền hệ thống") unless KEYS.include?(permission&.key)
  end
  def self.allowed?(actor:, key:)
    actor&.enabled_for_access? && KEYS.include?(key) && joins(:permission, :user)
      .exists?(user_id: actor.identity_id, users: { principal_user_id: nil, active: true }, permissions: { key: key })
  end
end
