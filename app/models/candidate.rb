class Candidate < ApplicationRecord
  include ObservableRecord
  enum :stage, { applied: "applied", screening: "screening", interview: "interview", offer: "offer", hired: "hired", rejected: "rejected" }, validate: true
  validates :full_name, :email, :position, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end
