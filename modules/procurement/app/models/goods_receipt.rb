class GoodsReceipt < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :purchase_order
  belongs_to :received_by, class_name: "User"
  has_many :lines, -> { order(:purchase_order_line_id) }, class_name: "GoodsReceiptLine", inverse_of: :goods_receipt, autosave: true, dependent: :restrict_with_exception
  encrypts :delivery_reference
  validates :code, :received_on, :idempotency_key, :content_digest, presence: true
  validates :status, inclusion: { in: %w[recording recorded] }
  validates :delivery_reference, length: { maximum: 200 }, allow_nil: true
  validate { same_company_as(:purchase_order, :received_by) }
  before_update { throw :abort if status_in_database == "recorded" }
  before_destroy { throw :abort }
end
