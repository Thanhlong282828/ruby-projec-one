class OutboxEvent < ApplicationRecord
  include CompanyOwned
  scope :pending, -> { where(delivered_at: nil) }
end
