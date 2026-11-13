class PurchaseOrderEvent < ApplicationRecord
  include CompanyOwned
  belongs_to :purchase_order
  belongs_to :actor, class_name: "User"
  encrypts :note
  validates :action, inclusion: { in: %w[created updated issued] }
  validates :version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  before_update { raise ActiveRecord::ReadOnlyRecord, "Purchase order history is immutable" }
  before_destroy { throw :abort }
  validate { same_company_as(:purchase_order, :actor) }
end
