class OutboxEvent < ApplicationRecord
  scope :pending, -> { where(delivered_at: nil) }
end
