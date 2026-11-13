class User < ApplicationRecord
  include CompanyOwned
  include PrincipalIdentity
  has_many :user_permissions, dependent: :destroy
  belongs_to :principal_user, class_name: "User", optional: true
  has_many :company_profiles, class_name: "User", foreign_key: :principal_user_id, inverse_of: :principal_user, dependent: :restrict_with_error
  has_secure_password validations: false
  validates :password, presence: true, if: -> { principal_user_id.nil? && password_digest.blank? }
  validates :password, confirmation: true, allow_nil: true
  validate do
    errors.add(:password, "quá 72 bytes") if password && password.bytesize > 72
    if password_challenge
      old = password_digest_in_database
      errors.add(:password_challenge, "không hợp lệ") unless old && BCrypt::Password.new(old).is_password?(password_challenge)
    end
    if persisted? && will_save_change_to_email? && company_profiles.exists?
      errors.add(:email, "cần quy trình đổi định danh toàn hệ thống")
    end
    if principal_user_id
      errors.add(:principal_user_id, "phải là định danh đăng nhập gốc") unless principal_user && principal_user.principal_user_id.nil? && principal_user.company_id != company_id
      errors.add(:password, "membership không sở hữu mật khẩu") if password_digest.present?
      errors.add(:email, "phải theo định danh gốc") if principal_user && email != principal_user.email
    end
    if persisted? && (will_save_change_to_principal_user_id? || will_save_change_to_company_id?)
      errors.add(:base, "Không được đổi chủ định danh/company; dùng membership mới")
    end
  end
  validate do
    if persisted? && principal_user_id.nil? && will_save_change_to_active? && !active?
      owner = SystemGrant.joins(:permission).exists?(user_id: id, permissions: { key: "system.companies.manage" })
      errors.add(:active, "thu hồi quyền quản trị tổng bằng quy trình riêng trước khi khóa định danh") if owner
    end
  end
  has_one :employee, dependent: :nullify
  has_many :api_tokens, dependent: :destroy
  has_many :login_sessions, dependent: :destroy
  after_update :revoke_credentials_after_security_change

  validates :active, inclusion: { in: [ true, false ] }
  normalizes :role, with: ->(value) { value.to_s.strip.downcase }
  validates :role, presence: true
  validate do
    errors.add(:role, "must exist in the account's company") if company_id && !CompanyRole.exists?(company_id: company_id, key: role)
  end
  # Compatibility predicates are labels only; policies use allowed? from MySQL.
  def admin? = role.to_s.strip.downcase == "admin"
  def hr? = role.to_s.strip.downcase == "hr"
  def manager? = role.to_s.strip.downcase == "manager"
  def employee? = role.to_s.strip.downcase == "employee"
  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, presence: true, uniqueness: { scope: :company_id }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12, maximum: 72 }, allow_nil: true
  # Always consult persisted grants. A deny override wins over the role grant.
  # No wildcard admin bypass and no hardcoded role->permission runtime mapping.
  def enabled_for_access?
    return false unless persisted? && User.joins(:company).exists?(id: id, company_id: company_id, role: role, active: true, companies: { active: true })
    !principal_user_id || User.where(id: principal_user_id, principal_user_id: nil, active: true).where.not(company_id: company_id).exists?
  end
  def effective_permission_keys
    return [] unless enabled_for_access?
    inherited = Permission.joins(role_permissions: :company_role).where(company_roles: { company_id: company_id, key: role }).pluck(:key)
    overrides = UserPermission.where(user_id: id).joins(:permission).pluck("permissions.key", :granted)
    (inherited + overrides.select { |_, granted| granted }.map(&:first)).uniq - overrides.reject { |_, granted| granted }.map(&:first)
  end
  def allowed?(key)
    key.to_s.start_with?("system.") ? SystemGrant.allowed?(actor: self, key: key.to_s) : effective_permission_keys.include?(key.to_s)
  end
  def staff? = admin? || hr?
  private
  def revoke_credentials_after_security_change
    if saved_change_to_password_digest? || saved_change_to_company_id? || (saved_change_to_active? && !active?)
      if principal_user_id.nil?
        ApiToken.where(principal_user_id: id).delete_all
        LoginSession.where(principal_user_id: id).delete_all
      else
        api_tokens.delete_all
        login_sessions.delete_all
      end
    end
  end
end
