class PurchaseRequest < ApplicationRecord
  include CompanyOwned
  include ObservableRecord
  belongs_to :created_by, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many :lines, -> { order(:position) }, class_name: "PurchaseRequestLine", inverse_of: :purchase_request, autosave: true, dependent: :restrict_with_exception
  has_many :events, class_name: "PurchaseRequestEvent", inverse_of: :purchase_request, dependent: :restrict_with_exception
  encrypts :purpose
  encrypts :rejection_reason
  validates :code, presence: true, uniqueness: { scope: :company_id }
  validates :title, presence: true, length: { maximum: 200 }
  validates :purpose, presence: true, length: { maximum: 4000 }
  validates :needed_on, presence: true
  validates :currency, inclusion: { in: [ "VND" ] }
  validates :status, inclusion: { in: HrmProcurement::Domain::Services::RequestFilters::STATUSES }
  validates :estimated_total, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: HrmProcurement::Domain::Services::RequestContent::MAX_TOTAL }
  validates :rejection_reason, presence: true, length: { maximum: 2000 }, if: -> { status == "rejected" }
  validate do
    same_company_as(:created_by)
    same_company_as(:reviewed_by) if reviewed_by
    errors.add(:base, "Người tạo không được tự duyệt") if reviewed_by_id && reviewed_by_id == created_by_id
    if persisted?
      errors.add(:base, "Không được đổi định danh phiếu") if %w[company_id created_by_id code currency].any? { |key| will_save_change_to_attribute?(key) }
      errors.add(:base, "Nội dung đã gửi không được sửa") if status_in_database != "draft" && %w[title purpose needed_on estimated_total].any? { |key| will_save_change_to_attribute?(key) }
      errors.add(:base, "Phiếu đã quyết định không được sửa") if %w[approved rejected].include?(status_in_database)
    end
  end
  before_destroy { throw :abort }
end
