class PurchaseRequestEvent < ApplicationRecord
  include CompanyOwned
  belongs_to :purchase_request, inverse_of: :events
  belongs_to :actor, class_name: "User"
  encrypts :note
  validates :action, inclusion: { in: %w[created updated submitted approved rejected] }
  validates :version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate { same_company_as(:purchase_request); same_company_as(:actor) }
  before_update { raise ActiveRecord::ReadOnlyRecord, "Lịch sử chỉ được thêm mới" }
  before_destroy { throw :abort }
end
