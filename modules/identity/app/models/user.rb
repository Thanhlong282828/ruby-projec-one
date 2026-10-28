class User < ApplicationRecord
  include CompanyOwned
  has_many :user_permissions, dependent: :destroy
  has_secure_password
  has_one :employee, dependent: :nullify
  has_many :api_tokens, dependent: :destroy
  validates :active, inclusion: { in: [true, false] }
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
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }, allow_nil: true
  # Always consult persisted grants. A deny override wins over the role grant.
  # No wildcard admin bypass and no hardcoded role->permission runtime mapping.
  def enabled_for_access?
    persisted? && User.joins(:company).where(id: id, company_id: company_id, role: role, active: true, companies: { active: true }).exists?
  end
  def effective_permission_keys
    return [] unless enabled_for_access?
    inherited = Permission.joins(role_permissions: :company_role).where(company_roles: { company_id: company_id, key: role }).pluck(:key)
    overrides = UserPermission.where(user_id: id).joins(:permission).pluck("permissions.key", :granted)
    (inherited + overrides.select { |_, granted| granted }.map(&:first)).uniq - overrides.reject { |_, granted| granted }.map(&:first)
  end
  def allowed?(key) = effective_permission_keys.include?(key.to_s)
  def staff? = admin? || hr?
end
