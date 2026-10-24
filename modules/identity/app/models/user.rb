class User < ApplicationRecord
  has_secure_password
  has_one :employee, dependent: :nullify
  has_many :api_tokens, dependent: :destroy
  enum :role, { employee: "employee", manager: "manager", hr: "hr", admin: "admin" }, validate: true
  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }, allow_nil: true
  def staff? = admin? || hr?
end
