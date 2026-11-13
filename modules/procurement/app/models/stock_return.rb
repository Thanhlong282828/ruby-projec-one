class StockReturn < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :stock_receipt
  belongs_to :warehouse
  belongs_to :supplier, class_name: "ProcurementSupplier"
  belongs_to :posted_by, class_name: "User"
  has_many :lines, -> { order(:stock_movement_id) }, class_name: "StockReturnLine", inverse_of: :stock_return, autosave: true, dependent: :restrict_with_exception
  encrypts :reason
  validates :code, :idempotency_key, :content_digest, :warehouse_code_snapshot, :warehouse_name_snapshot, :supplier_code_snapshot, :supplier_name_snapshot, presence: true
  validates :reason, presence: true, length: { maximum: 2000 }
  validates :status, inclusion: { in: %w[posting posted] }
  validate { same_company_as(:stock_receipt, :warehouse, :supplier, :posted_by) }
  before_update { throw :abort if status_in_database == "posted" }
  before_destroy { throw :abort }
end
