class PurchaseOrder < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :purchase_request
  belongs_to :supplier, class_name: "ProcurementSupplier", inverse_of: :purchase_orders
  belongs_to :created_by, class_name: "User"
  belongs_to :issued_by, class_name: "User", optional: true
  has_many :lines, -> { order(:position) }, class_name: "PurchaseOrderLine", inverse_of: :purchase_order, autosave: true, dependent: :restrict_with_exception
  has_many :events, class_name: "PurchaseOrderEvent", dependent: :restrict_with_exception
  encrypts :price_change_reason
  validates :code, presence: true, uniqueness: { scope: :company_id }
  validates :purchase_request_id, uniqueness: { scope: :company_id }
  validates :supplier_code_snapshot, :supplier_name_snapshot, :request_code_snapshot, :title_snapshot, :expected_on, presence: true
  validates :status, inclusion: { in: %w[draft issued] }
  validates :currency, inclusion: { in: [ "VND" ] }
  validates :price_change_reason, length: { maximum: 2000 }, allow_nil: true
  validates :ordered_total, :request_total_snapshot, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: HrmProcurement::Domain::Services::RequestContent::MAX_TOTAL }
  validate do
    same_company_as(:purchase_request, :supplier, :created_by)
    same_company_as(:issued_by) if issued_by
    if persisted?
      immutable = %w[company_id purchase_request_id supplier_id created_by_id code currency supplier_code_snapshot supplier_name_snapshot request_code_snapshot title_snapshot request_total_snapshot]
      errors.add(:base, "Không được đổi nguồn/snapshot PO") if immutable.any? { |key| will_save_change_to_attribute?(key) }
      errors.add(:base, "PO đã phát hành không được sửa") if status_in_database == "issued"
    end
  end
  before_destroy { throw :abort }
end
