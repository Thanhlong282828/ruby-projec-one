class StockReceipt < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :goods_receipt
  belongs_to :warehouse
  belongs_to :posted_by, class_name: "User"
  has_many :movements, -> { order(:goods_receipt_line_id) }, class_name: "StockMovement", inverse_of: :stock_receipt, autosave: true, dependent: :restrict_with_exception
  validates :code, :mapping_digest, :warehouse_code_snapshot, :warehouse_name_snapshot, presence: true
  validates :status, inclusion: { in: %w[posting posted] }
  validate { same_company_as(:goods_receipt, :warehouse, :posted_by) }
  before_update { throw :abort if status_in_database == "posted" }
  before_destroy { throw :abort }
end
